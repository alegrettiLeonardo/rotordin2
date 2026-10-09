!     $Id$
!     ==================================================================
!
!>    @file tcouprops.f
!>    @brief torsional coupling properties.
!>    last changes:<br>
!>    new file dec-19 - f.
!
!     ==================================================================
!>    @brief coupling equivalent section properties
!
!>    @param[in] cplgid coupling section ids
!>    @param[in] cplgst coupling stiffness
!>    @param[in] cplgdp coupling damping
!>    @param[in] cplgin coupling inertia
!>    @param[in] cplgsr coupling speed ratio
!>    @param[in] n number of divisions
!>    @param[in] Y main section positions
!>    @param[in] dely nodal distance
!>    @param[in] Ie y mass inertia
!>    @param[in] rs density
!>    @param[in] gs shear modulus
!>    @param[in] tsl torsional division length add
!>    @param[in] ps section positions
!>    @param[out] rssec values of density to result on coupling inertia
!>    @param[out] gssec values of shear module to result on coupling sti
!>    @param[out] ratsec speed ratio
!>    @param[out] dmpsec coupling damping
!>    @param[out] idsec index of coupling sections
!>    @param[out] ncsp number of couplinc division properties
!>    @param[in] ncp number of couplings
!>    @param[in] nn number of number of divisions n
!>    @param[in] mts divisions vectors dimension
!>    @param[in] mtt coupling division vetors dimension
!>    @param[in] mxs sections vector dimension
!>    @param[in] mxc coupling data vector dimension
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
subroutine tcouprops(cplgid,cplgst,cplgdp,cplgin,cplgsr,&
&n,Y,dely,Ie,rs,gs,tsl,ps,&
&rssec,gssec,ratsec,dmpsec,idsec,&
&ncsp,ncp,nn,mts,mtt,mxs,mxc,errmsg,ok)
  use rd_kinds, only: lrk, wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
!
  character(len=99) :: errmsg
  integer :: ncp, nn, ncsp, mts, mtt, mxs, mxc, ok
  integer :: cplgid
  real(lrk) :: cplgst, cplgdp, cplgin, cplgsr
  dimension cplgid(mxc),cplgst(mxc),cplgdp(mxc),&
  &cplgin(mxc),cplgsr(mxc)
  real(lrk) :: n, Y, dely, Ie, rs, gs, tsl, ps
  dimension n(mts),Y(mts),dely(mts),Ie(mts),rs(mts),&
  &gs(mts),tsl(mtt),ps(mxs)
!
  integer :: nsc, idsec
  real(lrk) :: ratsec, dmpsec
  real(wp) :: rssec, gssec
  dimension idsec(mtt),rssec(mtt),gssec(mtt),&
  &ratsec(mtt),dmpsec(mtt)
!
  real(lrk) :: fcp, icp, dtl
  real(wp) :: tj, tk, ack, acj
  real(lrk) :: cpk, cpj
!     index functions
  integer :: dividf, indypf
  integer :: ii, jj, kk, mm, cfi, cii, fci, ici

!     indices
  integer :: sci(mtt)
!     inertias,stiffness,distances,coupling fictive density,
!     couplig fictive shear modulus,speed ratio,coupling damping
  real(wp) :: scj, sck, cgs, crs
  real(lrk) :: dyc, spr, cdp
  dimension dyc(mtt),crs(mtt),&
  &scj(mtt),sck(mtt),cgs(mtt),&
  &spr(mtt),cdp(mtt)
!     minimum coupling inertia if not well defined
  real(lrk) :: precj
  parameter(precj = 1e-9_lrk)
!
!     init
!     return init
  ok = -1
!
  ncsp = 0
!     coupling loop
  do ii = 1,ncp
!       Passive coupling contract in reflected train coordinates.
    if (.not.ieee_is_finite(cplgdp(ii)).or..not.ieee_is_finite(cplgst(ii)).or. &
        .not.ieee_is_finite(cplgsr(ii))) then
      write(errmsg,'(a,i0,a)') 'A04 tcouprops: coupling ',ii,' requires finite stiffness, damping and speed ratio'
      return
    end if
    if (cplgdp(ii)<0._wp.or.cplgst(ii)<0._wp.or.cplgsr(ii)==0._wp) then
      write(errmsg,'(a,i0,a)') 'A04 tcouprops: coupling ',ii,' requires K,C>=0 and nonzero speed ratio'
      return
    end if
!       coupling section final position index
    jj = cplgid(ii)
    cfi = jj+1
!       coupling section initial position index
    cii = jj
!       final coupling position (m)
    fcp = ps(cfi-1)
!       final coupling index position
    fci = indypf(fcp,errmsg)
    if (fci .lt. 0) then
!         return with error
      return
    end if
!       initial coupling position (m)
    if (cii .gt. 1) then
      icp = ps(cii-1)
    else
      icp = 0
    end if
!       initial coupling index position
    ici = indypf(icp,errmsg)
    if (ici .lt. 1) then
!         return with error
      return
    end if
!       number of sections
    nsc = fci-ici
    if(nsc<1.or.ncsp+nsc>mtt) then
      write(errmsg,'(a,i0,a)') 'A04 tcouprops: coupling ',ii,' has invalid subdivision count'
      return
    end if
!
!       coupling sections
    do jj = 1,nsc
!         global section index
      kk = ici+jj-1
      sci(jj) = kk
!         section additional length
      dtl = tsl(kk)
      dyc(jj) = Y(kk+1)-Y(kk)+dtl
!         section inertia
!         compensate density here, just dely
      scj(jj) = rs(kk)*(Y(kk+1)-Y(kk))*2*Ie(kk)
      if(dyc(jj)<=0._wp.or.gs(kk)<=0._wp.or.Ie(kk)<=0._wp.or.scj(jj)<=0._wp) then
        write(errmsg,'(a,i0,a,i0)') 'A04 tcouprops: nonpositive geometry/material in coupling ',ii,', division ',kk
        return
      end if
!         section stiffness
      sck(jj) = gs(kk)*2*Ie(kk)/dyc(jj)
    end do
!       total inertia
    tj = 0
!       equivalent stiffness
    tk = 0
    do jj = 1,nsc
      tj = tj + scj(jj)
      tk = tk + 1/sck(jj)
    end do
    tk = 1/tk
!       coupling stiffness
    cpk = cplgst(ii)
!       coupling inertia
    cpj = cplgin(ii)
    if (cpj  .lt. precj) then
!         warning invalid coupling inertia
      call elmsgw(0,29,'tcouprops')
!         needed on two node inertia matrix
      cpj = precj
    end if
!       stiffness ratio:coupling/shaft
    ack = cpk/tk
!       inertia ratio:coupling/shaft
    acj = cpj/tj
!
    do jj = 1,nsc
!         global section index
      kk = ici+jj-1
!         Return density per physical length; tmatrices compensates for
!         equivalent compliance length exactly once when assembling J.
      crs(jj) = scj(jj)/(Y(kk+1)-Y(kk))/2/Ie(kk)*acj
      cgs(jj) = sck(jj)/2/Ie(kk)*dyc(jj)*ack
!         speed ratio
      spr(jj) = cplgsr(ii)
!         Kelvin-Voigt coupling subdivisions are in SERIES. Equal
!         relaxation time c_e/k_e preserves terminal K+i*w*C when their
!         internal inertias are neglected; equal parts require n*C.
!         The original elastic compliance weights also cover unequal
!         lengths/sections and equivalent torsional compliance lengths.
      cdp(jj) = cplgdp(ii)*sck(jj)/tk
    end do
!       results
    do jj = 1,nsc
      ncsp = ncsp+1
      idsec(ncsp) = sci(jj)
      rssec(ncsp) = crs(jj)
      gssec(ncsp) = cgs(jj)
      ratsec(ncsp) = spr(jj)
      dmpsec(ncsp) = cdp(jj)
    end do
!       coupling loop
  end do
!
  ok = 0
!
  return
!
end subroutine tcouprops
!
