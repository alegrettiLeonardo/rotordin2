!     ==================================================================
!>    A02 complex elastic recovery. theta contains reflected coordinates q.
!>    Physical element coordinates are phi = ratio*q, as in native r^2 K/J.
!>    leff includes only the existing equivalent compliance length.
!>    stress is NOMINAL circular-section shear; it is not a concentration,
!>    external torque, damping torque, or a physical coupling local stress.
!>    im=2 uses the piecewise-linear B associated with native tk3s; its
!>    inertia interpolation is inconsistent and production harmonic routes
!>    remain NOT_QUALIFIED. xi=0 selects the right-hand limiting derivative.
subroutine tqe_phasor(im,leff,shear,jpolar,radius,ratio,xi,theta,delta,torque,stress,errmsg,ok)
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer, intent(in) :: im
  real(wp), intent(in) :: leff,shear,jpolar,radius,ratio,xi
  complex(wp), intent(in) :: theta(3)
  complex(wp), intent(out) :: delta,torque,stress
  character(len=99), intent(out) :: errmsg
  integer, intent(out) :: ok
  real(wp) :: b(3),stiff
  integer :: nnode

  ok=-1; errmsg=''; delta=(0._wp,0._wp); torque=delta; stress=delta
  if (im/=1 .and. im/=2) then
    errmsg='A02: received invalid torsion element type; expected 1 (2 nodes) or 2 (3 nodes).'
    return
  end if
  if (.not.all(ieee_is_finite([leff,shear,jpolar,radius,ratio,xi]))) then
    errmsg='A02: nonfinite torsion recovery property; expected finite length, G, Jp, radius, ratio and xi.'
    return
  end if
  if (leff<=0._wp .or. shear<=0._wp .or. jpolar<=0._wp .or. radius<0._wp .or. ratio==0._wp) then
    errmsg='A02: invalid torsion recovery property; require L,G,Jp>0, radius>=0 and nonzero speed ratio.'
    return
  end if
  if (abs(xi)>1._wp) then
    errmsg='A02: torsion recovery coordinate xi outside [-1,1]; select a point inside the element.'
    return
  end if
  nnode=im+1
  if (.not.all(ieee_is_finite(real(theta(1:nnode),wp))) .or. &
      .not.all(ieee_is_finite(aimag(theta(1:nnode))))) then
    errmsg='A02: nonfinite angular phasor; torque/stress recovery rejected.'
    return
  end if
  ! Dimensionless derivatives: B = b/leff. No abs or small-angle cutoff.
  if (im==1) then
    b=[-1._wp,1._wp,0._wp]
  else if (xi<0._wp) then
    b=[-2._wp,2._wp,0._wp]
  else
    b=[0._wp,-2._wp,2._wp]
  end if
  delta=ratio*(theta(nnode)-theta(1))
  stiff=shear*jpolar/leff
  ! SUM, not complex DOT_PRODUCT: the kinematic map has no conjugation.
  torque=stiff*ratio*sum(b(1:nnode)*theta(1:nnode))
  stress=torque*(radius/jpolar)
  if (.not.all(ieee_is_finite([real(delta,wp),aimag(delta),real(torque,wp),aimag(torque), &
      real(stress,wp),aimag(stress)]))) then
    delta=(0._wp,0._wp); torque=delta; stress=delta
    errmsg='A02: overflow/nonfinite recovered torque or stress; check units and section properties.'
    return
  end if
  ok=0
end subroutine tqe_phasor

!>    Recover the complex elastic effort from the actual native element.
!>    xi=-1 is its left face, xi=+1 its right face. For two nodes it is constant.
subroutine tdvtrst_c(im,di,mtg,dl,xi,rd,tq,st,errmsg,ok)
  use rd_kinds, only: wp
  use com_sec, only: nt,y
  use com_sea, only: ie
  use com_sed, only: ds
  use com_sprat, only: crat
  use com_sprat2, only: gsst
  use com_eqvlen, only: tsl
  implicit none
  integer, intent(in) :: im,di,mtg
  complex(wp), intent(in) :: dl(mtg)
  real(wp), intent(in) :: xi
  complex(wp), intent(out) :: rd,tq,st
  character(len=99), intent(out) :: errmsg
  integer, intent(out) :: ok
  integer :: c1,nnode
  complex(wp) :: theta(3)

  ok=-1; errmsg=''; rd=(0._wp,0._wp); tq=rd; st=rd
  if ((im/=1 .and. im/=2) .or. di<1 .or. di>=nt) then
    errmsg='A02: invalid torsion recovery element/division; no adjacent shaft element is available.'
    return
  end if
  c1=(di-1)*im+1; nnode=im+1
  if (c1+nnode-1>mtg) then
    errmsg='A02: torsion phasor vector is shorter than the requested element connectivity.'
    return
  end if
  theta=(0._wp,0._wp)
  theta(1:nnode)=dl(c1:c1+nnode-1)
  call tqe_phasor(im,y(di+1)-y(di)+tsl(di),gsst(di),2*ie(di),ds(di+1)/2,crat(di), &
      xi,theta,rd,tq,st,errmsg,ok)
end subroutine tdvtrst_c

!     $Id$
!     ==================================================================
!
!>    @file ttrqdiv.f
!>    @brief torsion division torque and stress
!>    last changes:<br>
!>    new file feb-20 - f<br>
!>    added torsion stiffness calculation oct-20 - fjdf<br>
!>    added lenght correction on tqdivf - fjdf - jul-21.
!
!     ==================================================================
!>    @brief calculates torque on element between two divisions.
!>    returns angular displacement with speed ratio.
!
!>    @param[in] di division index, @see tdvtrst
!>    @param[in] rd relative angular displacement between divisions
!>    without speed ratio
!>    @param[out] tq torque on division
!>    @param[out] st maximum shear stress on division
!>    @return angular displacement with speed ratio
!
real(lrk) function tqdivf(di,rd,tq,st)
  use com_eqvlen, only: teql, tsl
  use com_sea, only: rs, es, gs, dely, s, ie, ump
  use com_sec, only: n, y, nt, nn
  use com_sed, only: ds, di_d, di_s
  use com_sprat, only: crat
  use com_sprat2, only: gsst
  use rd_kinds, only: lrk
  implicit none
!
  integer :: di
  real(lrk) :: rd, tq, st
!
!     all sections (divisions)
  integer :: mts
  parameter (mts = 999)
!
!     speed ratio
  integer :: mtt
  parameter (mtt = mts)
!
  integer :: mxs
  parameter (mxs = 99)
!     section equivalent length,division equivalent length
!
!     equivalent G
!
!     additional data by division
!
!     division diameters
!
  character(len=6) :: nmm
  real(lrk) :: gg, sr, s3, td, am, al, lc, riff
!     minimum angular displacement, below is zero
  parameter(nmm = 'tqdivf',am = 1e-9_lrk)
!
  intrinsic :: abs
!
!     invalid division index, out invalid data
  if (di+1 .gt. nt .or. di .lt. 1) then
    call elmsge(1,8,nmm)
  end if
!
!     speed ratio
  sr = crat(di)
!     real angular displacement with speed ratio
  s3 = sr*rd
!     displacement below minimum is zero
  td = riff(abs(s3) .lt. am,0._lrk,s3)
!     division length
  s3 = y(di+1)-y(di)
!     additional length - added 07/21 - fjdf
  al = tsl(di)
!     length correction
  lc = s3/(s3+al)
!     division shear modulus G (equivalent on coupling)
  gg = gsst(di)
!     torque
  tq = td*gg*ie(di)*2/s3*lc
!     external radius, up to next division
  s3 = ds(di+1)/2
!     max shear stress
  st = tq*s3/ie(di)/2
!     real angular displacement with speed ratio
  tqdivf = td
!
  return
!
end function tqdivf
!
!     ==================================================================
!>    @brief calculates torque on element between two divisions.
!>    returns real angular displacement with speed ratio.
!>    @see tqdivf.
!
!>    @param[in] di division index, @see tdvtrst
!>    @param[in] rd relative angular displacement between divisions
!>    without speed ratio
!>    @param[out] tq torque on division
!>    @param[out] st maximum shear stress on division
!>    @return real angular displacement with speed ratio
!
real(lrk) function tqdiv1f(di,rd,tq,st)
  use rd_kinds, only: lrk
  implicit none
!
  integer :: di
  real(lrk) :: rd, tq, st
!
  real(lrk) :: tqdivf
!
  tqdiv1f = tqdivf(di,rd,tq,st)
!
  return
!
end function tqdiv1f
!
!     ==================================================================
!>    @brief calculates torque on element between two divisions.
!
!>    @param[in] im torsion model index
!>    @param[in] di division index
!>    \verbatim
!>    one node
!>    mat. index      -> 1-----2-----3-----4
!>    division index  -> |--1--|--2--|--3--|
!>
!>    two node
!>    mat. index      -> 1--2--3--4--5--6--7
!>    division  index -> |--1--|--2--|--3--|
!>    \endverbatim
!>    @param[in] mtg angular displacement vector dimension
!>    @param[in] dl angular displacement vector
!>    @param[out] rd relative angular displacement on division
!>    with speed ratio
!>    @param[out] tq torque on division
!>    @param[out] st maximum shear stress on division
!
subroutine tdvtrst(im,di,mtg,dl,rd,tq,st)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: im, di, mtg
  real(lrk) :: rd, tq, st
  real(wp) :: dl
  dimension dl(mtg)
!
  integer :: c1, c2
  real(lrk) :: ad, tqdivf
!
  intrinsic :: real
!
!     matrix/vector indices
  if (im .eq. 1) then
!       one node model
    c2 = di+1
    c1 = di
  else
!       two node model
    c2 = di*2+1
    c1 = (di-1)*2+1
  end if
!     relative angular displacement between divisions
  ad = real(dl(c2)-dl(c1), lrk)
!     torque,max shear stress on division -> tq,st
!     rd with speed ratio
  rd = tqdivf(di,ad,tq,st)
!
  return
!
end subroutine tdvtrst
!
!     ==================================================================
!>    @brief torsion all division torque and stress.
!>    Relative angular displacement betwen divisions.
!>    \verbatim
!>      0---1-----2---3
!>      |-1-|--2--|-3-|
!>    \endverbatim
!
!>    @param[in] im torsion model index
!>    @param[in] ic response column index
!>    @param[in] dl angular displacements
!>    without speed ratio
!>    @param[out] tav divisions relative angular displacements
!>    @param[out] trq divisions torque
!>    @param[out] tau divisions stress
!>    @param[in] dm size of matrices
!>    @param[in] mtg first dimension of matrices
!>    @param[in] mrc columns dimension response
!
subroutine ttrqdiv(im,ic,dl,tav,trq,tau,dm,mtg,mrc)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: im, ic, dm, mtg, mrc
  real(lrk) :: tav, trq, tau
  real(wp) :: dl
  dimension dl(mtg),tav(mtg,mrc),trq(mtg,mrc),tau(mtg,mrc)
!
  real(lrk) :: rd, tq, st
  integer :: ii, m1
!
  if (im .eq. 1) then
!       model index
    m1 = dm-1
  else
    m1 = (dm-1)/2
  end if
!
  do ii = 1,m1
    call tdvtrst(im,ii,mtg,dl,rd,tq,st)
!       relative angular displacement between divisions
!       rd with speed ratio
    tav(ii,ic) = rd
!       torque
    trq(ii,ic) = tq
!       shear stress
    tau(ii,ic) = st
  end do
!
  return
!
end subroutine ttrqdiv
!
!     ==================================================================
!>    @brief calculates equivalent torsion stiffness on a division range
!>     1/keq = 1/k1+...+1/kn. Division range must be crescent.
!>    @param[in] iid initial division index.
!>    @param[in] ifd final division index.
!>    @param[in] ic response column index
!>    @param[in] tav divisions relative angular displacements
!>    @param[in] trq divisions torque
!>    @param[in] mtg first dimension of matrices
!>    @param[in] mrc columns dimension response
!>    @return equivalent torsion stiffness (Nm/rad).
real(lrk) function tstiff(iid,ifd,ic,tav,trq,mtg,mrc)
  use rd_kinds, only: lrk
  implicit none
!
  integer :: iid, ifd, ic, mtg, mrc
  real(lrk) :: tav, trq
  dimension tav(mtg,mrc),trq(mtg,mrc)
!
  integer :: ii
  real(lrk) :: stf, smt, tsf
!
  intrinsic :: abs
!
  tsf = 0
  smt = 0
  do ii = iid,ifd
    if (abs(tav(ii,ic)) .gt. 0) then
      stf = abs(trq(ii,ic)/tav(ii,ic))
      if (stf .gt. 0) smt = smt + 1/stf
    end if
  end do
!
  if (smt .gt. 0) tsf = 1/smt
  tstiff = tsf
!
  return
!
end function tstiff
!
!     ==================================================================
!>    @brief sum of displacements and torques on sections to calculate
!>     torsion sitffness.
!
!>    @param[in] ic response column index
!>    @param[in] tav divisions relative angular displacements
!>    @param[in] trq divisions torque
!>    @param[out] tsf equivalent stiffnes vector
!>    @param[out] nsf number of calculated equivalent stiffnes
!>    @param[in] mxts dimension of torsion equivalent stiffness vector
!>    @param[in] mtg first dimension of matrices
!>    @param[in] mrc columns dimension response
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine teqstf(ic,tav,trq,tsf,nsf,mxts,mtg,mrc,errmsg,ok)
  use rd_textfun, only: fomsgf
  use com_tman, only: ntbr, tpc, tkk, tcc, tjj, sct
  use com_tstest, only: eqstid, ntest
  use com_unb1, only: ndd, mu, ed, tpf, nb
  use rd_kinds, only: lrk
  implicit none
!
  integer :: ic, nsf, mxts, mtg, mrc, ok
  real(lrk) :: tsf, tav, trq
  character(len=99) :: errmsg
  dimension tsf(mxts,3),tav(mtg,mrc),trq(mtg,mrc)
!
!     input parameters
  integer :: mxm, mxb
  parameter (mxm = 9, mxb = 99)
!
!     torsion restriction bearings, added mar-21
!
!     unbalance
!     kind of exc
!     -1:transient torque,0:unbalance (default),1:concentrated,
!     2:harmonic torque,3:static torque,4:freq. response,5:dist. force
!
!     equivalent stiffness for static
  integer :: mxtstf
  parameter (mxtstf = 5)
!
  real(lrk) :: tstiff
  logical :: pok
  character(len=6) :: nmm
  character(len=22) :: csm
  integer :: ii, jj, kk, lj, lk, kst, oki, inddis
  parameter (kst = 3,nmm = 'teqstf',&
  &csm = 'torsion brg/static exc')
!
  intrinsic :: abs
!
  ok = -1
!     number of calculated equivalent stiffness
  nsf = 0
!
!     check for static excitation
  kk = 0
  do ii = 1,nb
    if (tpf(ii) .eq. kst) then
      kk = ii
      exit
    end if
  end do
!     is possible by having restriction and excitation
  pok = ntbr .gt. 0 .and. kk .gt. 0
!     check for possible equivalent stiffness calculation
  if(.not. pok .and. ntest .eq. 0) then
!        is not possible and desired to calculate, return ok
    ok = 0
    return
  end if
!     check for at least one restriction and one excitation
  if(.not. pok .and. ntest .gt. 0) then
!       too/few data
    errmsg = fomsgf(99, nmm,7,csm,0)
    return
  end if
!     check for restriction-torque definition on input
  if (ntest .eq. 0) then
!       no definition, default first bearing / torque
    ntest = 1
!       first torsion restriction number
    eqstid(1,1) = 1
!       excitation torque number
    eqstid(1,2) = kk
  end if
!
!     definite, bearing and torque
  do ii = 1,ntest
!       bearing number
    jj = eqstid(ii,1)
!       check index and if is torsion restriction
    if (jj .lt. 1 .or. jj .gt. ntbr) then
!         invalid index
      errmsg = fomsgf(99, nmm,27,csm,0)
      return
    end if
!       search torsion bearing section index
    lj = inddis(tpc(jj),errmsg,oki)
!       check if found
    if (oki .lt.0) return
!       search static excitation section index
    kk = eqstid(ii,2)
!       check index and if is torque
    if (kk .lt. 1 .or. kk .gt. nb .or. tpf(kk) .ne. kst) then
!         invalid index, not static torque
      errmsg = fomsgf(99, nmm,27,csm,0)
      return
    end if
    lk = inddis(ndd(kk),errmsg,oki)
    if (oki .lt.0) return
    if (lj .gt. lk) then
      if (lj .gt. 1) lj = lj-1
      tsf(ii,1) = tstiff(lk,lj,ic,tav,trq,mtg,mrc)
    else
      if (lk .gt. 1) lk = lk-1
      tsf(ii,1) = tstiff(lj,lk,ic,tav,trq,mtg,mrc)
    end if
!       bearing position
    tsf(ii,2) = tpc(jj)
!       torque position
    tsf(ii,3) = ndd(kk)
  end do
!     number of calculated equivalent stiffness
  nsf = ntest
!
  ok = 0
!
  return
!
end subroutine teqstf
!
