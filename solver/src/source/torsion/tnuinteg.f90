!     $Id$
!     ==================================================================
!
!>    @file tnuinteg.f
!>    @author francisco
!>    @date 06-feb-20
!>    @brief torsion numerical time integration routines, last changes:<
!>     new file - feb-20.
!
!     ==================================================================
!>    @brief generate result time vector
!
!>    @param[in] telap elapsed intergration time (s)
!>    @param[in] rsst result time step (s), if zero use load time steps
!>    @param[in] tload time load steps matrix (s)
!>    @param[in] ttrdsz number of time load steps
!>    @param[in] mxttrd input time torque matrix rows (time) dimension
!>    @param[in] mxttra input time torque matrix columns (positions) dim
!>    @param[in] mxttrs output time torque matrix columns (positions) di
!>    @param[out] nrstps number of result time step
!>    @param[out] restm  result time step vector
!>    @param[out] timev input time vector
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine rtsteps(telap,rsst,tload,&
&ttrdsz,mxttrd,mxttra,mxttrs,nrstps,restm,timev,ok)
  use rd_kinds, only: lrk
  implicit none
!
  integer :: ttrdsz, nrstps, mxttrd, mxttra, mxttrs, ok
  real(lrk) :: telap, rsst, tload, restm, timev
  dimension tload(mxttrd,mxttra+1),restm(mxttrs),timev(mxttrd)
!
  integer :: ii
  real(lrk) :: tt
!
  intrinsic :: nint
!
!     initialize return
  ok = -1
!
!     extract input time vector
  do ii = 1,ttrdsz
    timev(ii) = tload(ii,1)
  end do
!
  if (rsst .ge. 0) then
!       number of result time steps
    nrstps = nint(telap/rsst)+1
!       check bounds
    if (nrstps .gt. mxttrs) return
!       result time step vector
!       first time
    tt = tload(1,1)
    restm(1) = tt
    do ii = 2,nrstps
      tt = tt+rsst
      restm (ii) = tt
    end do
  else
    nrstps = ttrdsz
!       result time step vector
!       copy time load steps
    do ii = 1,nrstps
      restm(ii) = tload(ii,1)
    end do
  end if
!
!     return ok
  ok = 0
!
  return
!
end subroutine rtsteps
!
!     ==================================================================
!     @brief SPLINE integrpolation.
!>     use: given an 1D array of X data and an array of Y data, both of
!>     length N, this routine computes the 2nd derivatives, Y2 at each
!>     X data point.<br>
!>     This routine called once, prior to using routine SPLINT, as a
!>     set up for using routine SPLINT, which performs the actual
!>      interpolation.<br>
!>    \verbatim
!>    IMPORTANT NOTE: the X data values in array X must be in ascending
!>    order or the interpolation will fail.
!>    \endverbatim
!
!>    @param[in] x x data array
!>    @param[in] y y data array
!>    @param[in] n number of array elements.
!>    @param[in] mxttra input time torque matrix columns (positions) dim
!>    @param[out] y2 y derivatives
subroutine splined(x,y,n,mxttra,y2)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: n, mxttra
  real(lrk) :: x, y
  real(wp) :: y2
  dimension x(mxttra),y(mxttra),y2(mxttra)
!
  character(len=7) :: nmm
  real(wp) :: p, u, sig, dl1, dl2, dl3, prec
  dimension u(n)
  parameter (nmm = 'splined',prec = 1e-12_lrk)
  integer :: i
!
  intrinsic :: abs
!
!     zero vector u
  call zervec_d(u,n,n)
!
!     store intermediate values of terms in the expansion series
  do i = 2,n-1
!       division deltas
    dl1 = x(i+1)-x(i-1)
    dl2 = x(i+1)-x(i)
    dl3 = x(i)-x(i-1)
!       near zero division, stop
    if (dl1 <= 0._wp .or. dl2 <= 0._wp .or.&
    &dl3 <= 0._wp) call elmsge(1,7,nmm)
!
    sig = dl3/dl1
    p = sig*y2(i-1)+2.0_lrk
    y2(i) = (sig-1.0_lrk)/p
    u(i) = (6._lrk*((y(i+1)-y(i))/dl2-(y(i)-y(i-1))/dl3)/dl1-sig*u(i-1))/p
  end do
!
!     compute the Y2 from the 2nd order expansion series
  do i = n-1,1,-1
    y2(i) = y2(i)*y2(i+1)+u(i)
  end do
!
  return
!
end subroutine splined
!
!     ==================================================================
!>    @brief prepare load matrix interpolation derivatives
!
!>    @param[in] timev input time vector
!>    @param[in] tload time load matrix [{t},{l1},{l2}...}] ntloads x nl
!>    @param[in] ttrdsz size of time vector
!>    @param[in] nlind number of load indices
!>    @param[in] mxttrd input time torque matrix rows (time) dimension
!>    @param[in] mxttra input time torque matrix columns (positions) dim
!>    @param[out] itdxv last interpolation interval indices
!>    @param[out] y2mat derivatives matrix [{d1},{d2},...}] ntloads x nl
!
subroutine lminterp(timev,tload,ttrdsz,&
&nlind,mxttrd,mxttra,itdxv,y2mat)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: ttrdsz, nlind, itdxv, mxttrd, mxttra
  real(lrk) :: timev, tload
  real(wp) :: y2mat
  dimension timev(mxttrd),tload(mxttrd,mxttra+1),&
  &y2mat(mxttrd,mxttra),itdxv(mxttra)
!
  integer :: ii, jj
  real(lrk) :: valuev
  real(wp) :: y2
  dimension valuev(mxttrd),y2(mxttrd)
!
!     prepare intepolation index vector
  do jj = 1,nlind
    itdxv(jj) = 1
  end do
!
  do jj = 1,nlind
    do ii = 1,ttrdsz
!         load value vector
      valuev(ii) = tload(ii,jj+1)
    end do
    y2(1) = 0._wp
    y2(ttrdsz) = 0._wp
!       get derivatives vector each load -> y2
    call splined(timev,valuev,ttrdsz,mxttrd,y2)
!       prepare intepolation derivatives matrix
    do ii = 1,ttrdsz
      y2mat(ii,jj) = y2(ii)
    end do
  end do
!
  return
!
end subroutine lminterp
!
!     ==================================================================
!     @brief initialize displacement, velocity vectors to zero
!
!>    @param[out] uo initial displacementes
!>    @param[out] vo initial velocities
!>    @param[in] dm size of structural matrices stiffness and mass
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!
subroutine initval(uo,vo,dm,mtg)
  use rd_kinds, only: wp
  implicit none
!
  integer :: dm, mtg
  real(wp) :: uo, vo
  dimension uo(mtg),vo(mtg)
!
!     zero initial values

  call zervec_d(uo,dm,mtg)
  call zervec_d(vo,dm,mtg)
!
  return
!
end subroutine initval
!
!     ==================================================================
!     @brief assemble load vector
!
!>    @param[in] dm size of structural matrices
!>    @param[in] lind section indices to apply loads and initial values
!>     {id1,id2,...} nlind_ x 1
!>    @param[in] nlind number of load indices
!>    @param[in] loadv load dof load vector
!>    @param[in] mxttra input time torque matrix columns (positions)
!>     dimension
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[out] fo return load vector
!
subroutine loadvf(dm,lind,nlind,loadv,mxttra,mtg,fo)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: dm, lind, nlind, mxttra, mtg
  real(lrk) :: loadv
  real(wp) :: fo
  dimension lind(mxttra),loadv(mxttra),fo(mtg)
!
  integer :: jj, id
!
!     zeros -> fo
  call zervec_d(fo,dm,mtg)
!
  do jj = 1,nlind
    id = lind(jj)
    fo(id) =  loadv(jj)
  end do
!
  return
!
end subroutine loadvf
!
!     ==================================================================
!>    @brief calculate acceleration.
!>     a = 1/m * (f - k*x - c*v)
!
!>    @param[in] mm inertia matrix
!>    @param[in] kk stiffness matrix
!>    @param[in] cc viscous damping matrix
!>    @param[in] uo displacements vector
!>    @param[in] vo speed vector
!>    @param[in] fo force vector
!>    @param[in] dm size of structural matrices
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[out] wo acceleration vector
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine accel0f(mm,kk,cc,uo,vo,fo,dm,mtg,wo,errmsg,ok)
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer,intent(in) :: dm,mtg
  real(wp),intent(in) :: mm(mtg,mtg),kk(mtg,mtg),cc(mtg,mtg),uo(mtg),vo(mtg),fo(mtg)
  real(wp),intent(out) :: wo(mtg)
  character(len=99),intent(out) :: errmsg
  integer,intent(out) :: ok
  real(wp),allocatable :: lu(:,:),ku(:),cv(:),rhs(:),candidate(:),work(:)
  integer,allocatable :: ipiv(:),iwork(:)
  real(wp) :: mscale,anorm,rcond,eta,force_scale,ratio
  integer :: info
  logical :: torsion_matvec_representable
  ok=-1;errmsg=' ';wo=0._wp
  if(dm<1.or.dm>mtg) then
    errmsg='A05 accel0f: invalid dimension; require 1 <= dm <= matrix capacity';return
  end if
  if(.not.all(ieee_is_finite(mm(1:dm,1:dm))).or. &
     .not.all(ieee_is_finite(kk(1:dm,1:dm))).or. &
     .not.all(ieee_is_finite(cc(1:dm,1:dm))).or. &
     .not.all(ieee_is_finite(uo(1:dm))).or. &
     .not.all(ieee_is_finite(vo(1:dm))).or. &
     .not.all(ieee_is_finite(fo(1:dm)))) then
    errmsg='A05 accel0f: finite J,C,K,q0,v0,T0 required';return
  end if
  mscale=maxval(abs(mm(1:dm,1:dm)))
  if(mscale==0._wp) then
    errmsg='A05 accel0f: singular zero inertia matrix J';return
  end if
  allocate(lu(dm,dm),ku(dm),cv(dm),rhs(dm),candidate(dm),work(4*dm),ipiv(dm),iwork(dm))
  ! Uniform scaling avoids dependence of LU/condition estimation on inertia
  ! units. It does not change the equation and does not form an inverse.
  lu=mm(1:dm,1:dm)/mscale
  anorm=maxval(sum(abs(lu),dim=2))
  call dgetrf(dm,dm,lu,dm,ipiv,info)
  if(info/=0) then
    write(errmsg,'(a,i0,a,i0)') 'A05 accel0f: singular/invalid J; LU info=',info,', dofs=',dm
    return
  end if
  call dgecon('I',dm,lu,dm,anorm,rcond,work,iwork,info)
  if(info/=0.or..not.ieee_is_finite(rcond)) then
    errmsg='A05 accel0f: inertia condition estimate failed';return
  end if
  if(rcond<=epsilon(1._wp)*real(dm,wp)) then
    write(errmsg,'(a,es10.2,a,i0)') 'A05 accel0f: ill-conditioned inertia; rcond=',rcond,', dofs=',dm
    return
  end if
  ! Physical equilibrium at the initial instant:
  ! J*a0 = T0 - C*v0 - K*q0. Both internal forces oppose excitation.
  if(.not.torsion_matvec_representable(kk,uo,dm,mtg,mtg)) then
    errmsg='A05 accel0f: elastic torque intermediate exceeds real64 range; rescale model';return
  end if
  if(.not.torsion_matvec_representable(cc,vo,dm,mtg,mtg)) then
    errmsg='A05 accel0f: damping torque intermediate exceeds real64 range; rescale model';return
  end if
  ku=matmul(kk(1:dm,1:dm),uo(1:dm))
  cv=matmul(cc(1:dm,1:dm),vo(1:dm))
  if(.not.all(ieee_is_finite(ku)).or..not.all(ieee_is_finite(cv))) then
    errmsg='A05 accel0f: nonfinite initial elastic or damping torque';return
  end if
  force_scale=max(maxval(abs(fo(1:dm))),maxval(abs(ku)),maxval(abs(cv)))
  rhs=0._wp
  if(force_scale>0._wp) then
    rhs=fo(1:dm)/force_scale-cv/force_scale-ku/force_scale
    if(mscale<1._wp) then
      if(force_scale>huge(1._wp)*mscale) then
        errmsg='A05 accel0f: initial torque/inertia scale exceeds real64 capacity';return
      end if
    end if
    ratio=force_scale/mscale
    if(maxval(abs(rhs))>1._wp) then
      if(ratio>huge(1._wp)/maxval(abs(rhs))) then
        errmsg='A05 accel0f: scaled initial RHS exceeds real64 capacity';return
      end if
    end if
    rhs=rhs*ratio
  end if
  candidate=rhs
  call dgetrs('N',dm,1,lu,dm,ipiv,candidate,dm,info)
  if(info/=0) then
    write(errmsg,'(a,i0)') 'A05 accel0f: initial acceleration LU solve failed; info=',info
    return
  end if
  if(.not.all(ieee_is_finite(candidate))) then
    errmsg='A05 accel0f: nonfinite initial acceleration';return
  end if
  ! Independently reconstruct the ORIGINAL signed equilibrium, not the
  ! RHS buffer used by LU. Publish acceleration only after this gate.
  call torsion_initial_residual(mm,kk,cc,uo,vo,fo,candidate,dm,mtg,dm,eta,info)
  if(info/=0) then
    if(info==-2) then
      errmsg='A05 accel0f: equilibrium torque intermediate exceeds real64 range; rescale model';return
    end if
    write(errmsg,'(a,es10.2,a,i0)') 'A05 accel0f: initial equilibrium residual failed; eta=',eta,', dofs=',dm
    return
  end if
  wo(1:dm)=candidate
  ok=0
end subroutine accel0f

!> Physical published acceleration using a cached, scaled inertia LU.
!> Same signed equilibrium and residual gate as A05; no algorithmic feedback.
subroutine torsion_published_acceleration(mm,kk,cc,q,v,f,lu,ipiv,mscale,dm,ld,a,errmsg,ok)
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer,intent(in) :: dm,ld,ipiv(ld)
  real(wp),intent(in) :: mm(ld,ld),kk(ld,ld),cc(ld,ld),q(ld),v(ld),f(ld),lu(ld,ld),mscale
  real(wp),intent(out) :: a(ld)
  character(len=99),intent(out) :: errmsg
  integer,intent(out) :: ok
  real(wp) :: ku(dm),cv(dm),rhs(dm),force_scale,ratio,eta
  integer :: info
  logical :: torsion_matvec_representable
  ok=-1;errmsg=' ';a=0._wp
  if(.not.all(ieee_is_finite(q(1:dm))).or..not.all(ieee_is_finite(v(1:dm))).or. &
     .not.all(ieee_is_finite(f(1:dm)))) then
    errmsg='REV-02 publication: nonfinite displacement, velocity or load';return
  end if
  if(.not.torsion_matvec_representable(kk,q,dm,ld,ld).or. &
     .not.torsion_matvec_representable(cc,v,dm,ld,ld)) then
    errmsg='REV-02 publication: elastic/damping torque exceeds real64 range';return
  end if
  ku=matmul(kk(1:dm,1:dm),q(1:dm));cv=matmul(cc(1:dm,1:dm),v(1:dm))
  force_scale=max(maxval(abs(f(1:dm))),maxval(abs(ku)),maxval(abs(cv)))
  rhs=0._wp
  if(force_scale>0._wp) then
    rhs=f(1:dm)/force_scale-cv/force_scale-ku/force_scale
    if(mscale<1._wp) then
      if(force_scale>huge(1._wp)*mscale) then
        errmsg='REV-02 publication: torque/inertia scale exceeds real64 range';return
      end if
    end if
    ratio=force_scale/mscale
    if(maxval(abs(rhs))>1._wp) then
      if(ratio>huge(1._wp)/maxval(abs(rhs))) then
        errmsg='REV-02 publication: scaled RHS exceeds real64 range';return
      end if
    end if
    rhs=rhs*ratio
  end if
  call dgetrs('N',dm,1,lu,ld,ipiv,rhs,dm,info)
  if(info/=0.or..not.all(ieee_is_finite(rhs))) then
    errmsg='REV-02 publication: physical acceleration LU solve failed';return
  end if
  call torsion_initial_residual(mm,kk,cc,q,v,f,rhs,dm,ld,dm,eta,info)
  if(info/=0) then
    write(errmsg,'(a,es10.2,a,i0)') 'REV-02 publication: equilibrium residual/range failed; eta=',eta,', info=',info
    return
  end if
  a(1:dm)=rhs;ok=0
end subroutine torsion_published_acceleration

!> Physical initial-equilibrium residual with independent signed terms.
!> eta = ||J*a + C*v + K*q - T||inf /
!>       (||J*a||inf + ||C*v||inf + ||K*q||inf + ||T||inf).
!> Common torque scaling avoids an overflowing denominator and preserves
!> cancellation information; dimension/finite failures never publish PASS.
subroutine torsion_initial_residual(mm,kk,cc,q,v,f,a,dm,ld,la,eta,ok)
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer,intent(in) :: dm,ld,la
  real(wp),intent(in) :: mm(ld,ld),kk(ld,ld),cc(ld,ld),q(ld),v(ld),f(ld),a(la)
  real(wp),intent(out) :: eta
  integer,intent(out) :: ok
  real(wp),allocatable :: ma(:),cv(:),kq(:),res(:)
  real(wp) :: scale_t,den,tol
  logical :: torsion_matvec_representable
  ok=-1;eta=huge(1._wp)
  if(dm<1.or.dm>ld.or.dm>la) return
  if(.not.all(ieee_is_finite(mm(1:dm,1:dm))).or. &
     .not.all(ieee_is_finite(cc(1:dm,1:dm))).or. &
     .not.all(ieee_is_finite(kk(1:dm,1:dm))).or. &
     .not.all(ieee_is_finite(q(1:dm))).or..not.all(ieee_is_finite(v(1:dm))).or. &
     .not.all(ieee_is_finite(f(1:dm))).or..not.all(ieee_is_finite(a(1:dm)))) return
  if(.not.torsion_matvec_representable(mm,a,dm,ld,la).or. &
     .not.torsion_matvec_representable(cc,v,dm,ld,ld).or. &
     .not.torsion_matvec_representable(kk,q,dm,ld,ld)) then
    ok=-2;return
  end if
  allocate(ma(dm),cv(dm),kq(dm),res(dm))
  ma=matmul(mm(1:dm,1:dm),a(1:dm));cv=matmul(cc(1:dm,1:dm),v(1:dm))
  kq=matmul(kk(1:dm,1:dm),q(1:dm))
  if(.not.all(ieee_is_finite(ma)).or..not.all(ieee_is_finite(cv)).or..not.all(ieee_is_finite(kq))) return
  scale_t=max(maxval(abs(ma)),maxval(abs(cv)),maxval(abs(kq)),maxval(abs(f(1:dm))))
  if(scale_t==0._wp) then
    eta=0._wp;ok=0;return
  end if
  ma=ma/scale_t;cv=cv/scale_t;kq=kq/scale_t
  res=ma+cv+kq-f(1:dm)/scale_t
  den=maxval(abs(ma))+maxval(abs(cv))+maxval(abs(kq))+maxval(abs(f(1:dm)/scale_t))
  eta=maxval(abs(res))/den
  tol=1000._wp*epsilon(1._wp)*real(dm,wp)
  if(ieee_is_finite(eta)) then
    if(eta<=tol) ok=0
  end if
end subroutine torsion_initial_residual

!> Conservative pre-arithmetic bound for a real64 matrix-vector product.
!> n*max(abs(A))*max(abs(x)) <= huge(real64) bounds every intermediate
!> product and row accumulation without ever evaluating an overflowing
!> product. It can reject a cancellation-dominated extreme case; it must
!> not let Debug SIGFPE replace a contextual initial-equilibrium error.
logical function torsion_matvec_representable(mat,vec,n,ld,lv) result(safe)
  use rd_kinds, only: wp
  implicit none
  integer,intent(in) :: n,ld,lv
  real(wp),intent(in) :: mat(ld,ld),vec(lv)
  real(wp) :: am,vm,limit
  safe=.false.
  if(n<1.or.n>ld.or.n>lv) return
  am=maxval(abs(mat(1:n,1:n)));vm=maxval(abs(vec(1:n)))
  if(am==0._wp.or.vm==0._wp) then
    safe=.true.;return
  end if
  limit=huge(1._wp)/real(n,wp)
  if(vm>1._wp) then
    safe=am<=limit/vm
  else if(am<=limit) then
    safe=.true.
  else
    safe=am*vm<=limit
  end if
end function torsion_matvec_representable
!
!     ==================================================================
!>    @brief initialize result matrices u,du/dt,d2u/dt2 []nrstps x nrind
!
!>    @param[in] rind result indices vector
!>    @param[in] nrind number of result indices
!>    @param[in] uo initial displacements
!>    @param[in] vo initial velocities
!>    @param[in] wo initial accelerations
!>    @param[in] mxttrs output time torque matrix rows (time) dimension
!>    @param[in] mxo result vector dimension
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[out] resum displacements matrix [] nrstps x nrind
!>    @param[out] resvm velocities matrix [] nrstps x nrind
!>    @param[out] resam accelerations matrix [] nrstps x nrind
!
subroutine preprm(rind,nrind,uo,vo,wo,mxttrs,mxo,mtg,&
&resum,resvm,resam)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: rind, nrind, mxttrs, mxo, mtg
  real(lrk) :: resum, resvm, resam
  real(wp) :: uo, vo, wo
  dimension rind(mxo),uo(mtg),vo(mtg),wo(mtg),&
  &resum(mxttrs,mxo),resvm(mxttrs,mxo),resam(mxttrs,mxo)
  integer :: jj, id
!
  intrinsic :: real
!
!     initial results
!
  do jj = 1,nrind
!       result index
    id = rind(jj)
!       displacement
    resum(1,jj) = real(uo(id), lrk)
!       velocity
    resvm(1,jj) = real(vo(id), lrk)
!       acceleration
    resam(1,jj) = real(wo(id), lrk)
  end do
!
  return
!
end subroutine preprm
!
!     ==================================================================
!>    @brief integration constants
!
!>    @param[in] imt numerical integration method
!>     0 = Newmark 1 = Wilson-theta
!>    @param[in] intst integration time step (s)
!>    @param[out] a integration constans vector as per imt
!>    @param[out] tet Wilson - theta amplitude decay factor
!>    @param[in] mxc integration constans vector appropriate dimension
!
subroutine itegcte(imt,intst,a,tet,mxc)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: imt, mxc
  real(lrk) :: intst, tet
  real(wp) :: a
  dimension a(0:mxc)
!
  character(len=7) :: nmm
!     alfa,delta -> Newmark amplitude decay factor
!     theta -> Wilson - theta amplitude decay factor
  real(lrk) :: alfa, delta, theta
  parameter (nmm = 'itegcte',alfa = 0.254_lrk, delta = 0.5_lrk,theta = 1.4_lrk)
!
!     integration constants
  if (imt .eq. 0) then
!       check dimension stop if not enough
    if (mxc .lt. 5) call elmsge(1,4,nmm)
!       Newmark
    a(0) = 1/(alfa*intst**2)
    a(1) = 1*delta/(alfa*intst)
    a(2) = a(0)*intst
    a(3) = 1/(2*alfa)-1
    a(4) = 1*delta/alfa-1
    a(5) = 1*(delta/(2*alfa)-1)*intst
  else if (imt .eq. 1) then
    if (mxc .lt. 8) call elmsge(1,4,nmm)
!       Wilson - theta
    a(0) = 6/(theta*intst)**2
    a(1) = 3/(theta*intst)
    a(2) = 2*a(1)
    a(3) = theta*intst/2
    a(4) = a(0)/theta
    a(5) = -1*a(2)/theta
    a(6) = 1-3/theta
    a(7) = intst/2
    a(8) = intst**2/6
    tet = theta
  else
!       stop if invalid integration kind
    call elmsge(1,6,nmm)
  end if
!
  return
!
end subroutine itegcte
!
!     ==================================================================
!>    @brief calculate effective stiffness matrix.
!>     ke = kk+a0*mm+a1*cc
!
!>    @param[in] kk stiffness matrix [kk]dm x dm
!>    @param[in] mm inertia matrix [mm]dm x dm
!>    @param[in] cc viscous damping matrix [cc]dm x dm
!>    @param[in] a0 integration constant
!>    @param[in] a1 integration constant
!>    @param[in] dm size of structural matrices
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[out] ke effective stiffness matrix
!
subroutine effstif(kk,mm,cc,a0,a1,dm,mtg,ke)
  use rd_kinds, only: wp
  implicit none
!
  integer :: dm, mtg
  real(wp) :: kk, mm, cc, ke, a0, a1
  dimension kk(mtg,mtg),mm(mtg,mtg),cc(mtg,mtg),ke(mtg,mtg)
!
  real(wp) :: aom, a1c
  dimension aom(mtg,mtg),a1c(mtg,mtg)
!
!     a0*mm -> aom
  call escmat_d(mm,aom,a0,dm,dm,mtg,mtg)
!
!     a1*cc -> a1c
  call escmat_d(cc,a1c,a1,dm,dm,mtg,mtg)
!
!     a0*mm(aom)+a1*cc(a1c) -> aom
  call sommat_d(aom,a1c,aom,dm,dm,mtg,mtg)
!
!     kk+(a0*mm+a1*cc)(aom) -> ke
  call sommat_d(kk,aom,ke,dm,dm,mtg,mtg)
!
  return
!
end subroutine effstif
!
!     ==================================================================
!>    @brief two last time load buffer
!
!>    @param[in] tid integration time index
!>    @param[in] nlind number of load indices
!>    @param[in] loadv load dof load vector
!>    @param[in,out] lb load dof load vector buffer
!>    @param[in] mxttra input time torque matrix columns (positions) dim
!
subroutine ipldbf(tid,nlind,loadv,lb,mxttra)
  use rd_kinds, only: lrk
  implicit none
!
  integer :: tid, nlind, mxttra
  real(lrk) :: loadv, lb
  dimension loadv(mxttra),lb(2,mxttra)
!
  integer :: jj
!
  if (tid .gt. 2) then
!       after first time
    do jj = 1,nlind
      lb(1,jj) = lb(2,jj)
      lb(2,jj) = loadv(jj)
    end do
  else
!       first time
    do jj = 1,nlind
      lb(2,jj) = loadv(jj)
    end do
  end if
!
  return
!
end subroutine ipldbf
!
!     ==================================================================
!>    @brief two last time results buffer
!
!>    @param[in] tid integration time index
!>    @param[in] rind result indices
!>    @param[in] nrind number of result indices
!>    @param[in] uo last displacement result index 2
!>    @param[in] vo last velocity result index 2
!>    @param[in] wo last acceleration result index 2
!>    @param[in] mxo result vector dimension
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[in,out] ub displacement buffer
!>    @param[in,out] vb velocity buffer
!>    @param[in,out] wb acceleration buffer
!
subroutine resbuf(tid,rind,nrind,uo,vo,wo,mxo,mtg,ub,vb,wb)
  use rd_kinds, only: wp
  implicit none
!
  integer :: tid, rind, nrind, mxo, mtg
  real(wp) :: ub, vb, wb, uo, vo, wo
  dimension rind(mxo),uo(mtg),vo(mtg),wo(mtg),&
  &ub(2,mtg),vb(2,mtg),wb(2,mtg)
!
  integer :: jj, id
!
  if (tid .gt. 2) then
!       after first time
    do jj = 1,nrind
!         result index
      id = rind(jj)
!         displacement
      ub(1,jj) = ub(2,jj)
      ub(2,jj) = uo(id)
!         velocity
      vb(1,jj) = vb(2,jj)
      vb(2,jj) = vo(id)
!         acceleration
      wb(1,jj) = wb(2,jj)
      wb(2,jj) = wo(id)
    end do
  else
!       first time
    do jj = 1,nrind
!         result index
      id = rind(jj)
!         displacement
      ub(2,jj) = uo(id)
!         velocity
      vb(2,jj) = vo(id)
!         acceleration
      wb(2,jj) = wo(id)
    end do
  end if
!
  return
!
end subroutine resbuf
!
!     ==================================================================
!>    @brief  SPLINE interpolation.
!>     SPLINT use: given an 1D array of XA data, an array of YA
!>     data, and an array of the 2nd derivatives Y2A, all of length N,
!>     this routine performs cubic spline interpolation, returning the
!>     interpolated value Y at the user input value X.
!>     The Y2A are computed in routine SPLINE, which is called once
!>     before calling SPLINT.
!>    \verbatim
!>     IMPORTANT NOTE: the X data values in array X must be in ascending
!>     order or the interpolation will fail.
!>    \endverbatim
!>    @param[in] xa input x data array
!>    @param[in] ya input y data array
!>    @param[in] y2 2nd order derivatives
!>    @param[in] x input x to interpolate y
!>    @param[in] n number of input data array elements
!>    @param[in] mxd dimension of vectors
!>    @param[out] y interpolated output
!>    @param[in,out] klo index, speed search
!
subroutine splint(xa,ya,y2,x,n,mxd,y,klo)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: n, klo, mxd
  real(lrk) :: xa, ya, x, y
  real(wp) :: y2
  dimension xa(mxd),ya(mxd),y2(mxd)
!
  character(len=6) :: nmm
  logical :: rpeqf, xeq
  integer :: k, khi
  real(wp) :: dl, a, b, yd
  real(lrk) :: eps
  parameter (eps = 1e-12_lrk,nmm = 'splint')
!
  intrinsic :: abs, int, real
!
  k = 0
  klo=max(1,min(klo,n-1))
  if(x<xa(klo)) klo=1
  khi = n
!     determine the indices of array XA that bracket the input X value
  do while (khi-klo .gt. 1)
    k = int((khi+klo)/2)
    if (xa(k) .gt. x) then
      khi = k
    else
      klo = k
    end if
  end do
!
!     determine the finite difference along the X dimension
!     true means both x are too close
  xeq = xa(khi)<=xa(klo)
  if (xeq) then
!       stop if x are too close, invalid data
    call elmsge(1,8,nmm)
  else
    if (x==xa(khi)) then
      y = ya(khi)
    else if (x==xa(klo)) then
      y = ya(klo)
    else
      dl = xa(khi)-xa(klo)
!         interpolate
      a = (xa(khi)-x)/dl
      b = (x-xa(klo))/dl
      yd = a*ya(klo)+b*ya(khi)+((a**3-a)*y2(klo)+(b**3-b)*y2(khi))*(dl**2)/6._lrk
      y = real(yd, lrk)
    end if
!
  end if
!
!     start new search before
  klo=max(1,min(klo,n-1))
!
  return
!
end subroutine splint
!
!     ==================================================================
!>    @brief interpolate time loads
!
!>    @param[in] tper input time period
!>    @param[in] tt interpolation time
!>    @param[in] timev input time vector
!>    @param[in] y2mat time load derivatives matrix
!>    @param[in,out] itdxv intepolation index vector
!>    @param[in] tload time loads matrix, first column time
!>     [{t},{l1},{l2}...]ntloads x lint
!>    @param[in] ttrdsz size of time vector
!>    @param[in] nlind number of load indices
!>    @param[in] nper number of input time period
!>    @param[in] mxttrd input time torque matrix rows (time) dimension
!>    @param[in] mxttra input time torque matrix columns (positions) dim
!>    @param[out] loadv load vector interpolated to integration time ste
!
subroutine ldinterp(tper,tt,timev,y2mat,itdxv,tload,&
&ttrdsz,nlind,nper,mxttrd,mxttra,loadv)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: itdxv, ttrdsz, nlind, nper, mxttrd, mxttra
  real(lrk) :: tload, tper, tt, timev, loadv
  real(wp) :: y2mat
  dimension timev(mxttrd),itdxv(mxttra),tload(mxttrd,mxttra+1),&
  &y2mat(mxttrd,mxttra),loadv(mxttra)
!
  real(lrk) :: prec
!     precision
  parameter (prec = 5e-4_lrk)
!
  integer :: ii, jj, itper
  real(lrk) :: ttim, valuev, pert
  real(wp) :: y2vec
  dimension valuev(mxttrd),y2vec(mxttrd)
!
  intrinsic :: abs, int
!
!     Absolute input times; repeat relative to the first table time.
  itper=0
  ttim=tt
  if(tt>timev(ttrdsz)) then
    pert=(tt-timev(1))/tper
    itper=int(pert)
    ttim=timev(1)+modulo(tt-timev(1),tper)
    if(ttim==timev(1)) then
      ttim=timev(ttrdsz)
      itper=max(0,itper-1)
    end if
  end if
  if(itper/=nper) itdxv(1:nlind)=1
!
!     interpolate load on time
  do jj = 1,nlind
    do ii = 1,ttrdsz
!         extract time step load values
      valuev(ii) = tload(ii,jj+1)
!         extract derivatives
      y2vec(ii) = y2mat(ii,jj)
    end do
!      interpolate each load on time step
    call splint(timev,valuev,y2vec,ttim,ttrdsz,mxttrd,&
    &loadv(jj),itdxv(jj))
  end do
!
!     return period index
  nper = itper
!
  return
!
end subroutine ldinterp
!
!     ==================================================================
!>    @brief time force vector
!
!>    @param[in] mm inertia matrix [mm]dm x dm
!>    @param[in] cc viscous damping matrix [cc]dm x dm
!>    @param[in] uo initial displacements
!>    @param[in] vo initial velocities
!>    @param[in] wo initial accelerations
!>    @param[in] a integration constants vector
!>    @param[in] ff current force vector
!>    @param[in] fo previous force vector
!>    @param[out] fn calculated force vector
!>    @param[out] pp new force vector
!>    @param[in] tet Wilson-theta theta constant
!>    @param[in] imt numerical integration method
!>     0 = Newmark 1 = Wilson-theta
!>    @param[in] dm size of structural matrices
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[in] nci integration constants vector dimension
!
subroutine tforvec(mm,cc,uo,vo,wo,a,ff,fo,fn,pp,tet,imt,&
&dm,mtg,nci)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: imt, dm, mtg, nci
  real(lrk) :: tet
  real(wp) :: mm, cc, a, pp, uo, vo, wo, ff, fo, fn
  dimension mm(mtg,mtg),cc(mtg,mtg),uo(mtg),vo(mtg),wo(mtg),&
  &a(0:nci),ff(mtg),fo(mtg),fn(mtg),pp(mtg)
!
  character(len=1) :: c1
  parameter (c1 = 'N')
  integer :: jj
  real(wp) :: v1, v2, p1, p2
  dimension v1(mtg,1),v2(mtg,1),p1(mtg,1),p2(mtg,1)
!
  intrinsic :: real
!
  do jj = 1,dm
    if (imt .eq. 0) then
!         Newmark
      fn(jj) = ff(jj)
      v1(jj,1) = a(0)*uo(jj)+a(2)*vo(jj)+a(3)*wo(jj)
      v2(jj,1) = a(1)*uo(jj)+a(4)*vo(jj)+a(5)*wo(jj)
    else if (imt .eq. 1) then
!         Wilson-theta
      fn(jj) = fo(jj)+tet*(ff(jj)-fo(jj))
      v1(jj,1) = a(0)*uo(jj)+a(2)*vo(jj)+2*wo(jj)
      v2(jj,1) = a(1)*uo(jj)+2*vo(jj)+a(3)*wo(jj)
    end if
  end do
!
!     multiplies (mm * v1) -> p1
!      call DGEMM ('N','N', dm, 1, dm, dble(1.), mm, mtg,
  call DGEMM (c1,c1, dm, 1, dm, real(1._lrk, wp), mm, mtg,v1, mtg, real(0._lrk, wp), p1, mtg)
!
!     multiplies (cc * v2) -> p2
!      call DGEMM ('N','N', dm, 1, dm, dble(1.), cc, mtg,
  call DGEMM (c1,c1, dm, 1, dm, real(1._lrk, wp), cc, mtg,v2, mtg, real(0._lrk, wp), p2, mtg)
!
!     result force vector
  do jj = 1,dm
    pp(jj) = fn(jj)+p1(jj,1)+p2(jj,1)
  end do
!
  return
!
end subroutine tforvec
!
!     ==================================================================
!>    @brief new displacements, velocities and acceleration
!
!>    @param[in] uu calculated displacements
!>    @param[in] uo previous displacement
!>    @param[in] vo previous velocity
!>    @param[in] wo previous acceleration
!>    @param[out] un new displacement
!>    @param[out] vn new velocity
!>    @param[out] wn new acceleration
!>    @param[in] a integration constants vector
!>    @param[in] intst integration time step (s)
!>    @param[in] imt numerical integration method
!>     0 = Newmark 1 = Wilson-theta
!>    @param[in] dm size of structural matrices
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[in] nci integration constants vector dimension
!
subroutine newdisp(uu,uo,vo,wo,un,vn,wn,a,intst,&
&imt,dm,mtg,nci)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: imt, dm, mtg, nci
  real(lrk) :: intst
  real(wp) :: uu, a, uo, vo, wo, un, vn, wn
  dimension uu(mtg),uo(mtg),vo(mtg),wo(mtg),&
  &un(mtg),vn(mtg),wn(mtg),a(0:nci)
!
  integer :: jj
!
  do jj = 1,dm
    if (imt .eq. 0) then
!         Newmark
      un(jj) = uu(jj)
!         new acceleration
      wn(jj) = a(0)*(un(jj)-uo(jj))-a(2)*vo(jj)-a(3)*wo(jj)
!         new speed
      vn(jj) = a(1)*(un(jj)-uo(jj))-a(4)*vo(jj)-a(5)*wo(jj)
    else if (imt .eq. 1) then
!         Wilson-theta
      wn(jj) = a(4)*(uu(jj)-uo(jj))+a(5)*vo(jj)+a(6)*wo(jj)
      vn(jj) = vo(jj)+a(7)*(wn(jj)+wo(jj))
      un(jj) = uo(jj)+intst*vo(jj)+a(8)*(wn(jj)+2*wo(jj))
    end if
  end do
!
  return
!
end subroutine newdisp
!
!     ==================================================================
!>    @brief load time interpolation
!
!>    @param[in] rid result index
!>    @param[in] nlind number of load indices
!>    @param[in] tt time step
!>    @param[in] tx result time step
!>    @param[in] restm result time vector
!>    @param[in] lb load dof load vector buffer
!>    @param[in] loadv load dof load vector
!>    @param[out] iptld result input loads
!>    @param[in] mxttrs output time torque matrix rows (time) dimension
!>    @param[in] mxttra input time torque matrix columns (pos.) dimensio
!>    @param[in] mxo result vector dimension
!
subroutine ldint(rid,nlind,tt,tx,restm,lb,loadv,&
&iptld,mxttrs,mxttra,mxo)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: rid, nlind, mxttrs, mxttra, mxo
  real(lrk) :: tt, tx, restm, lb, loadv, iptld
  dimension restm(mxttrs),lb(2,mxttra),&
  &loadv(mxttra),iptld(mxttrs,mxo)
!
  real(lrk) :: prec
!     equals precision
  parameter (prec = 1E-8_lrk)
  integer :: jj
!     functions
  real(wp) :: lin2pf, a1f, a2f, b2f, f2f
!     local result vectors
  real(wp) :: x1, x2, x3, y1, y2, y3, a1, a2, b2, ld, dtx
!
  intrinsic :: real
!
!     double time for interpolation
  dtx = tt
!
!     load
  do jj = 1,nlind
!
    if (abs(tt-tx) .le. prec)then
!         no need to interpolate
      ld = loadv(jj)
    else
!         interpolate
      if (rid .lt. 3) then
!           linear two points interpolation
        x1 = restm(1)
        x2 = tt
!           loads
        y1 = lb(2,jj)
        y2 = loadv(jj)
        ld = lin2pf(x1,y1,x2,y2,dtx)
      else
!           cubic spline three points interpolation
        x1 = restm(rid-2)
        x2 = restm(rid-1)
        x3 = tt
!           loads
        y1 = lb(1,jj)
        y2 = lb(2,jj)
        y3 = loadv(jj)
        a1 = a1f(x1,x2,x3,y1,y2,y3)
        a2 = a2f(a1,x1,x2,x3)
        b2 = b2f(x1,x2,x3,y1,y2,y3)
        ld = f2f(a2,b2,x3,y3,dtx)
      end if
    end if
!
    iptld(rid,jj) = real(ld, lrk)
!
  end do
!
  return
!
end subroutine ldint
!
!     ==================================================================
!>    @brief interpolated results.
!>     if necessary output results is interpolated using three points
!>     spline interpolation
!
!>    @param[in] rid result index
!>    @param[in] rind section indices to get results {id1,id2,...} nrind
!>    @param[in] nrind number of result indices
!>    @param[in] tt time step
!>    @param[in] tx result time step
!>    @param[in] restm result time vector
!>    @param[in] ub last two displacement integration result buffer
!>    @param[in] vb last two velocity integration result buffer
!>    @param[in] wb last two acceleration integration result buffer
!>    @param[in] uo displacement integration result
!>    @param[in] vo velocity integration result
!>    @param[in] wo acceleration integration
!>    @param[in] mxttrs output time torque matrix rows (time) dimension
!>    @param[in] mxo result vector dimension
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[out] resum displacement vector {} nrind x 1
!>    @param[out] resvm resv  velocity vector {} nrind x 1
!>    @param[out] resam acceleration vector {} nrind x 1
!
subroutine rinterp(rid,rind,nrind,tt,tx,restm,&
&ub,vb,wb,uo,vo,wo,mxttrs,mxo,mtg,resum,resvm,resam)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: rid, rind, nrind, mxttrs, mxo, mtg
  real(lrk) :: tt, tx, restm, resum, resvm, resam
  real(wp) :: ub, vb, wb, uo, vo, wo
  dimension rind(mxo),restm(mxttrs),ub(2,mtg),vb(2,mtg),wb(2,mtg),&
  &uo(mtg),vo(mtg),wo(mtg),&
  &resum(mxttrs,mxo),resvm(mxttrs,mxo),resam(mxttrs,mxo)
!
  real(lrk) :: prec
!     equals precision
  parameter (prec = 1E-8_lrk)
!
  integer :: jj, id
!     functions
  real(wp) :: lin2pf, a1f, a2f, b2f, f2f
!     local result vectors
  real(wp) :: x1, x2, x3, y1, y2, y3, a1, a2, b2, ru, rv, ra, dtx
!
  intrinsic :: real
!
  dtx = tx
!     loop on result indices
  do jj = 1,nrind
!       get result id
    id = rind(jj)
!
    if (abs(tt-tx) .le. prec)then
!         no need to interpolate
      ru = uo(id)
      rv = vo(id)
      ra = wo(id)
    else
!         interpolate
      if (rid .lt. 3) then
!           linear two points interpolation
        x1 = restm(1)
        x2 = tt
!           displacement
        y1 = ub(2,jj)
        y2 = uo(id)
        ru = lin2pf(x1,y1,x2,y2,dtx)
!           velocity
        y1 = vb(2,jj)
        y2 = vo(id)
        rv = lin2pf(x1,y1,x2,y2,dtx)
!           acceleration
        y1 = wb(2,jj)
        y2 = wo(id)
        ra = lin2pf(x1,y1,x2,y2,dtx)
      else
!           cubic spline three points interpolation
        x1 = restm(rid-2)
        x2 = restm(rid-1)
        x3 = tt
!           displacement
        y1 = ub(1,jj)
        y2 = ub(2,jj)
        y3 = uo(id)
        a1 = a1f(x1,x2,x3,y1,y2,y3)
        a2 = a2f(a1,x1,x2,x3)
        b2 = b2f(x1,x2,x3,y1,y2,y3)
        ru = f2f(a2,b2,x3,y3,dtx)
!           velocity
        y1 = vb(1,jj)
        y2 = vb(2,jj)
        y3 = vo(id)
        a1 = a1f(x1,x2,x3,y1,y2,y3)
        a2 = a2f(a1,x1,x2,x3)
        b2 = b2f(x1,x2,x3,y1,y2,y3)
        rv = f2f(a2,b2,x3,y3,dtx)
!           acceleration
        y1 = wb(1,jj)
        y2 = wb(2,jj)
        y3 = wo(id)
        a1 = a1f(x1,x2,x3,y1,y2,y3)
        a2 = a2f(a1,x1,x2,x3)
        b2 = b2f(x1,x2,x3,y1,y2,y3)
        ra = f2f(a2,b2,x3,y3,dtx)
      end if
    end if
!
    resum(rid,jj) = real(ru, lrk)
    resvm(rid,jj) = real(rv, lrk)
    resam(rid,jj) = real(ra, lrk)
!
  end do
!
  return
!
end subroutine rinterp
!
!     ==================================================================
!>    @brief torsion numerical integration.
!>    returns angular displacement, velocities and accelerations
!
!>    @param[in] mm inertia matrix [mm]dm x dm
!>    @param[in] cc viscous damping matrix [cc]dm x dm
!>    @param[in] kk stiffness matrix [kk]dm x dm
!>    @param[in] dm size of structural matrices
!>    @param[in] ttrdsz size of time vector
!>    @param[in] tper input time period. used for periodic input
!>     shorter than integration time, same as integration instead.
!>    @param[in] tload time loads matrix, first column time
!>     [{t},{l1},{l2}...]ntloads x lint+1
!>    @param[in] lind section indices to apply loads and
!>     initial values {id1,id2,...} nlind x 1
!>    @param[in] nlind number of load indices
!>    @param[in] initit initial integration time (s)
!>    @param[in] endit final integration time (s)
!>    @param[in] intst integration time step (s)
!>    @param[in] imt numerical integration method
!>     0 = Newmark 1 = Wilson-theta
!>    @param[in] rind section indices to get results
!>     {id1,id2,...} nrind x 1
!>    @param[in] nrind number of result indices
!>    @param[in] rsst results time step (s)
!>    @param[in] nrstps number of result time vector
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[in] mxo result vector dimension
!>    @param[in] mxttrd input time torque matrix rows (time) dimension
!>    @param[in] mxttra input time torque matrix columns (pos.) dimensio
!>    @param[in] mxttrs output time torque matrix columns (positions) di
!>    @param[out] restm time matrix
!>    @param[out] resum displacement matrix
!>    @param[out] resvm result velocity matrix
!>    @param[out] resam result acceleration matrix
!>    @param[out] iptld result input loads
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine tnuinteg(mm,cc,kk,dm,ttrdsz,tper,tload,&
&lind,nlind,initit,endit,intst,imt,rind,nrind,&
&rsst,nrstps,restm,resum,resvm,resam,iptld,&
&mtg,mxo,mxttrd,mxttra,mxttrs,errmsg,ok)
  use rd_kinds, only: lrk,wp
  use rd_torsion_time
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer :: dm,ttrdsz,lind,nlind,imt,rind,nrind,nrstps,mtg,mxo,mxttrd,mxttra,mxttrs,ok
  real(lrk) :: tper,tload,initit,endit,intst,rsst,restm,resum,resvm,resam,iptld
  real(wp) :: mm,cc,kk
  dimension mm(mtg,mtg),cc(mtg,mtg),kk(mtg,mtg),tload(mxttrd,mxttra+1), &
    lind(mxttra),rind(mxo),restm(mxttrs),resum(mxttrs,mxo), &
    resvm(mxttrs,mxo),resam(mxttrs,mxo),iptld(mxttrs,mxo)
  character(len=99) :: errmsg
  integer,parameter :: nci=8
  integer :: jj,oki,tid,rid,nper,nsteps,nrows,ipiv(mtg),itdxv(mxttra),mass_piv(mtg),pubidx(mxttra),pubper
  real(wp) :: timev(mxttrd),y2mat(mxttrd,mxttra),a(0:nci),tet,tt,tnext,h,hfact,tx,s,ds,mass_scale
  real(wp) :: uo(mtg),vo(mtg),wo(mtg),un(mtg),vn(mtg),wn(mtg), &
    ke(mtg,mtg),fo(mtg),ff(mtg),fn(mtg),pp(mtg),uu(mtg), &
    loadv(mxttra),loadpub(mxttra),qpub(mtg),vpub(mtg),apub(mtg),fpub(mtg),mass_lu(mtg,mtg)
  logical :: started,valid(3*mxo+mxttra)
  ok=-1;errmsg=' ';nrstps=0;started=.false.
  call torsion_time_reset(initit,endit)
  if(dm<1.or.dm>mtg.or.nrind<1.or.nrind>mxo.or.nlind<1.or.nlind>mxttra.or.nlind>mxo) then
    errmsg='REV-01 tnuinteg: invalid matrix/result/load dimensions';goto 900
  end if
  if(ttrdsz<2.or.ttrdsz>mxttrd.or.mxttrs<2) then
    errmsg='REV-01 tnuinteg: require at least two load/output rows within capacity';goto 900
  end if
  if(imt<0.or.imt>1) then
    errmsg='REV-01 tnuinteg: integration method must be Newmark or Wilson';goto 900
  end if
  if(any(lind(1:nlind)<1).or.any(lind(1:nlind)>dm).or. &
     any(rind(1:nrind)<1).or.any(rind(1:nrind)>dm)) then
    errmsg='REV-01 tnuinteg: load/result degree of freedom outside matrix';goto 900
  end if
  if(.not.all(ieee_is_finite(tload(1:ttrdsz,1:nlind+1))).or..not.ieee_is_finite(tper)) then
    errmsg='REV-01 tnuinteg: finite load table and period required';goto 900
  end if
  if(tper<=0._wp) then
    errmsg='REV-01 tnuinteg: positive input period required';goto 900
  end if
  timev(1:ttrdsz)=tload(1:ttrdsz,1)
  call torsion_time_check_table(timev(1:ttrdsz),ttrdsz,maxval(abs(tload(1:ttrdsz,2:nlind+1))),errmsg,oki)
  if(oki/=0) goto 900
  call torsion_time_plan(initit,endit,intst,nsteps,errmsg,oki)
  if(oki/=0) goto 900
  if(initit<timev(1)) then
    errmsg='REV-01 tnuinteg: initial time precedes the load table';goto 900
  end if
  ! Bound the periodic cache index before ldinterp converts cycles to integer.
  if(endit>timev(ttrdsz)) then
    call torsion_time_plan(timev(1),endit,tper,jj,errmsg,oki)
    if(oki/=0) goto 900
  end if
  call torsion_time_grid(initit,endit,rsst,mxttrs,nrows,restm,errmsg,oki)
  if(oki/=0) goto 900
  call torsion_time_allocate(nsteps,nrows,3*nrind+nlind)
  resum=0._wp;resvm=0._wp;resam=0._wp;iptld=0._wp
  call progress_begin('TORSION_TRANSIENT',nsteps+1,'torsional numerical time integration')
  started=.true.
  call progress_stage('TORSION_TRANSIENT','prepare load interpolation and effective stiffness')
  call lminterp(timev,tload,ttrdsz,nlind,mxttrd,mxttra,itdxv,y2mat)
  call initval(uo,vo,dm,mtg)
  tt=initit;nper=0
  call ldinterp(tper,tt,timev,y2mat,itdxv,tload,ttrdsz,nlind,nper,mxttrd,mxttra,loadv)
  call loadvf(dm,lind,nlind,loadv,mxttra,mtg,fo)
  call accel0f(mm,kk,cc,uo,vo,fo,dm,mtg,wo,errmsg,oki)
  if(oki/=0) goto 900
  call preprm(rind,nrind,uo,vo,wo,mxttrs,mxo,mtg,resum,resvm,resam)
  iptld(1,1:nlind)=loadv(1:nlind)
  valid(1:nrind)=ieee_is_finite(resum(1,1:nrind))
  valid(nrind+1:2*nrind)=ieee_is_finite(resvm(1,1:nrind))
  valid(2*nrind+1:3*nrind)=ieee_is_finite(resam(1,1:nrind))
  valid(3*nrind+1:3*nrind+nlind)=ieee_is_finite(iptld(1,1:nlind))
  call torsion_time_mark(1,initit,valid(1:3*nrind+nlind),errmsg,oki)
  if(oki/=0) goto 900
  ! accel0f has qualified the original inertia and its conditioning. Cache
  ! the same uniformly scaled LU for physical acceleration publication.
  mass_scale=maxval(abs(mm(1:dm,1:dm)))
  mass_lu(1:dm,1:dm)=mm(1:dm,1:dm)/mass_scale
  call dgetrf(dm,dm,mass_lu,mtg,mass_piv,jj)
  if(jj/=0) then
    errmsg='REV-02 publication: inertia LU failed after initial equilibrium';goto 900
  end if
  pubidx=1;pubper=0
  hfact=-1._wp;rid=2
  do tid=1,nsteps
    call torsion_time_next(initit,endit,intst,tid,nsteps,tt,tnext,h,errmsg,oki)
    if(oki/=0) goto 900
    if(h<sqrt(8._wp/huge(1._wp)).or.h>sqrt(huge(1._wp))/2._wp) then
      errmsg='REV-01 tnuinteg: final-step coefficients exceed real64 range';goto 900
    end if
    if(h/=hfact) then
      call itegcte(imt,h,a,tet,nci)
      call effstif(kk,mm,cc,a(0),a(1),dm,mtg,ke)
      call dgetrf(dm,dm,ke,mtg,ipiv,jj)
      if(jj/=0) then
        write(errmsg,'(a,i0)') 'REV-01 tnuinteg: effective-stiffness LU failed; info=',jj
        goto 900
      end if
      hfact=h
    end if
    call ldinterp(tper,tnext,timev,y2mat,itdxv,tload,ttrdsz,nlind,nper,mxttrd,mxttra,loadv)
    call loadvf(dm,lind,nlind,loadv,mxttra,mtg,ff)
    call tforvec(mm,cc,uo,vo,wo,a,ff,fo,fn,pp,tet,imt,dm,mtg,nci)
    call copv_dd(pp,uu,dm,mtg,mtg)
    call dgetrs('N',dm,1,ke,mtg,ipiv,uu,dm,jj)
    if(jj/=0) then
      write(errmsg,'(a,i0)') 'REV-01 tnuinteg: effective solve failed; info=',jj
      goto 900
    end if
    call newdisp(uu,uo,vo,wo,un,vn,wn,a,h,imt,dm,mtg,nci)
    if(.not.all(ieee_is_finite(un(1:dm))).or..not.all(ieee_is_finite(vn(1:dm))).or. &
       .not.all(ieee_is_finite(wn(1:dm)))) then
      errmsg='REV-01 tnuinteg: nonfinite integrated state';goto 900
    end if
    ! Wilson extrapolates from physical endpoint loads, not from its previous
    ! theta-extrapolated force. Internal acceleration remains algorithmic.
    call torsion_time_advanced(tnext,h)
    ! F6.1 progress must not round a partial increment to 100.0 percent.
    if(real(tid+1,wp)/real(nsteps+1,wp)<=.999_wp) &
      call progress_update('TORSION_TRANSIENT',tid+1,nsteps+1,tnext,'TIME_S')
    ! Consume EVERY requested instant in this actual integrated interval.
    ! q/v use one Hermite polynomial; a is independently recovered from EOM.
    do while(rid<=nrows)
      tx=restm(rid)
      if(tx>tnext) exit
      if(tx<tt) then
        errmsg='REV-02 publication: requested instant precedes current bracket';goto 900
      end if
      if(tx==tnext) then
        qpub(1:dm)=un(1:dm);vpub(1:dm)=vn(1:dm)
      else if(tx==tt) then
        qpub(1:dm)=uo(1:dm);vpub(1:dm)=vo(1:dm)
      else
        s=(tx-tt)/h
        do jj=1,dm
          ds=un(jj)-uo(jj)
          qpub(jj)=uo(jj)+(3._wp*s*s-2._wp*s*s*s)*ds &
            +h*(s*s*s-2._wp*s*s+s)*vo(jj)+h*(s*s*s-s*s)*vn(jj)
          vpub(jj)=(6._wp*s-6._wp*s*s)*ds/h &
            +(3._wp*s*s-4._wp*s+1._wp)*vo(jj)+(3._wp*s*s-2._wp*s)*vn(jj)
        end do
      end if
      call ldinterp(tper,tx,timev,y2mat,pubidx,tload,ttrdsz,nlind,pubper,mxttrd,mxttra,loadpub)
      call loadvf(dm,lind,nlind,loadpub,mxttra,mtg,fpub)
      call torsion_published_acceleration(mm,kk,cc,qpub,vpub,fpub,mass_lu,mass_piv,mass_scale, &
        dm,mtg,apub,errmsg,oki)
      if(oki/=0) goto 900
      iptld(rid,1:nlind)=loadpub(1:nlind)
      do jj=1,nrind
        resum(rid,jj)=qpub(rind(jj));resvm(rid,jj)=vpub(rind(jj));resam(rid,jj)=apub(rind(jj))
      end do
      valid(1:nrind)=ieee_is_finite(resum(rid,1:nrind))
      valid(nrind+1:2*nrind)=ieee_is_finite(resvm(rid,1:nrind))
      valid(2*nrind+1:3*nrind)=ieee_is_finite(resam(rid,1:nrind))
      valid(3*nrind+1:3*nrind+nlind)=ieee_is_finite(iptld(rid,1:nlind))
      call torsion_time_mark(rid,tx,valid(1:3*nrind+nlind),errmsg,oki)
      if(oki/=0) goto 900
      rid=rid+1
    end do
    ! Publication never feeds physical recovered acceleration back into
    ! Wilson's algorithmic state, nor changes endpoint forcing/state.
    fo(1:dm)=ff(1:dm)
    uo(1:dm)=un(1:dm);vo(1:dm)=vn(1:dm);wo(1:dm)=wn(1:dm)
    tt=tnext
  end do
  call torsion_time_finish(errmsg,oki)
  if(oki/=0) goto 900
  nrstps=nrows;ok=0
  if(.not.torsion_time_is_deferred()) then
    call torsion_time_emit_report()
    call progress_update('TORSION_TRANSIENT',nsteps+1,nsteps+1,tt,'TIME_S')
    call progress_end('TORSION_TRANSIENT','OK')
  end if
  return
900 continue
  nrstps=0;ok=-1
  call torsion_time_emit_report()
  if(started) call progress_end('TORSION_TRANSIENT','FAIL')
  return
end subroutine tnuinteg
!
!     ==================================================================
!>    @brief torsion numerical integration.
!>    returns only angular displacement
!
!>    @param[in] mm inertia matrix [mm]dm x dm
!>    @param[in] cc viscous damping matrix [cc]dm x dm
!>    @param[in] kk stiffness matrix [kk]dm x dm
!>    @param[in] dm size of structural matrices
!>    @param[in] ttrdsz size of time vector
!>    @param[in] tper input time period. used for periodic input
!>     shorter than integration time, same as integration instead.
!>    @param[in] tload time loads matrix, first column time
!>     [{t},{l1},{l2}...]ntloads x lint+1
!>    @param[in] lind section indices to apply loads and
!>     initial values {id1,id2,...} nlind x 1
!>    @param[in] nlind number of load indices
!>    @param[in] initit initial integration time (s)
!>    @param[in] endit final integration time (s)
!>    @param[in] intst integration time step (s)
!>    @param[in] imt numerical integration method
!>     0 = Newmark 1 = Wilson-theta
!>    @param[in] rind section indices to get results
!>     {id1,id2,...} nrind x 1
!>    @param[in] nrind number of result indices
!>    @param[in] rsst results time step (s)
!>    @param[in] nrstps number of result time vector
!>    @param[in] iptld result input loads
!>    @param[in] mtg structural matrices mm,kk,cc dimension
!>    @param[in] mxo result vector dimension
!>    @param[in] mxttrd input time torque matrix rows (time) dimension
!>    @param[in] mxttra input time torque matrix columns (pos.) dimensio
!>    @param[in] mxttrs output time torque matrix columns (positions) di
!>    @param[out] restm time matrix
!>    @param[out] resum displacement matrix
!>    @param[out] errmsg return an error message
!>    @param[out] ok return flag. unsuccessful if <0.
!
subroutine tnuintegu(mm,cc,kk,dm,ttrdsz,tper,tload,&
&lind,nlind,initit,endit,intst,imt,rind,nrind,&
&rsst,nrstps,restm,resum,iptld,&
&mtg,mxo,mxttrd,mxttra,mxttrs,errmsg,ok)
  use rd_kinds, only: lrk, wp
  implicit none
!
  integer :: dm, ttrdsz, lind, nlind, imt, rind, nrind, nrstps, mtg, mxo, mxttrd, mxttra, mxttrs, ok
  real(lrk) :: tper, tload, initit, endit, intst, rsst, restm, resum, iptld
  real(wp) :: mm, cc, kk
  dimension mm(mtg,mtg),cc(mtg,mtg),kk(mtg,mtg),&
  &tload(mxttrd,mxttra+1),&
  &lind(mxttra),rind(mxo),&
!      results
  &restm(mxttrs),resum(mxttrs,mxo),iptld(mxttrs,mxo)
  character(len=99) :: errmsg
!
  real(lrk) :: resvm, resam
  dimension resvm(mxttrs,mxo),resam(mxttrs,mxo)
!
  call tnuinteg(mm,cc,kk,dm,ttrdsz,tper,tload,&
  &lind,nlind,initit,endit,intst,imt,rind,nrind,&
  &rsst,nrstps,restm,resum,resvm,resam,iptld,&
  &mtg,mxo,mxttrd,mxttra,mxttrs,errmsg,ok)
!
  return
!
end subroutine tnuintegu
!
