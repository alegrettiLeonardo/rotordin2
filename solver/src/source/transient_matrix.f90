!
!     Physical matrix update for the true transient solver.
!
subroutine transient_angular_acceleration_contract(errmsg,ok)
  ! A07: the existing deck specifies speed, not how its driving torque does
  ! generalized work on tilt. A follower torque, an inertial-axis torque and
  ! a torque conjugate to the Euler spin coordinate give different alpha terms.
  ! Do not silently select one. Constant profiles and rotation-free controls
  ! remain valid; affected ramps stop before initialization/integration.
  use com_mat, only: mg,mka,dm
  use com_trnctl, only: trn_speed_kind,trn_nprof
  use com_trnprof, only: trn_prpm
  implicit none
  character(*), intent(out) :: errmsg
  integer, intent(out) :: ok
  integer :: i
  logical :: varying
  ok=0; errmsg=''; varying=.false.
  if (trn_speed_kind/=1) then
    do i=2,trn_nprof
      if (trn_prpm(i)/=trn_prpm(i-1)) varying=.true.
    enddo
  endif
  if (varying .and. (any(mg(1:dm,1:dm)/=0).or.any(mka(1:dm,1:dm)/=0))) then
    ok=-1
    errmsg='A07 NOT_QUALIFIED: variable spin needs drive torque/tilt-work contract; use constant RPM'
  endif
end subroutine transient_angular_acceleration_contract

subroutine transient_compose_rotation(n,ld,omega,alpha,gyro,ka,kbase,cbase,kphys,cphys)
  ! Algebraic kernel for a DECLARED prescribed-Euler-spin/zero-tilt-work model.
  ! The production wrapper must establish its angular-acceleration contract.
  use rd_kinds, only: wp
  implicit none
  integer, intent(in) :: n,ld
  real(wp), intent(in) :: omega,alpha,gyro(ld,ld),ka(ld,ld),kbase(ld,ld),cbase(ld,ld)
  real(wp), intent(out) :: kphys(ld,ld),cphys(ld,ld)
  ! Only the active block belongs to this model (ld is the fixed capacity).
  kphys(1:n,1:n)=kbase(1:n,1:n)+alpha*ka(1:n,1:n)
  cphys(1:n,1:n)=cbase(1:n,1:n)+omega*gyro(1:n,1:n)
end subroutine transient_compose_rotation

subroutine transient_check_bearing_range(rpm,errmsg,ok)
  use com_knd, only: cknd, supr
  use com_nbc, only: cp, scl, bc
  use com_pmk, only: nt, kmc, cmc, rmc
  use rd_kinds, only: lrk, wp
  implicit none
  integer :: mpm, mxm
  parameter(mxm=9,mpm=99)
  real(wp) :: rpm
  character(len=*) :: errmsg
  integer :: ok, i, j
  ok=-1
  if(cknd.ne.'2') then
    ok=0
    return
  endif
  do i=1,cp
    if(nt(i).lt.2) then
      errmsg='transient: bearing table needs at least two points'
      return
    endif
    do j=2,nt(i)
      if(rmc(i,j).le.rmc(i,j-1)) then
        errmsg='transient: bearing-table RPM must be increasing'
        return
      endif
    enddo
    if(rpm.lt.real(rmc(i,1), wp)-1e-7_wp .or.rpm.gt.real(rmc(i,nt(i)), wp)+1e-7_wp) then
      write(errmsg,'(A,F14.4,A,I3,A,F14.4,A,F14.4,A)')&
      &'transient: RPM ',rpm,' outside bearing table ',i,&
      &' [',rmc(i,1),',',rmc(i,nt(i)),']'
      return
    endif
  enddo
  ok=0
  return
end subroutine transient_check_bearing_range
!
subroutine transient_matrix_update(dm,pp,rpm,omega,alpha,&
&mass,gyro,kbase,cbase,kphys,cphys,errmsg,ok)
  use com_mat, only: mm, mg, mka, gdm => dm, smn
  use com_mtk, only: mk1
  use rd_kinds, only: lrk, wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer :: mtg
  parameter(mtg=500)
  integer :: dm, pp, ok, oki, i, j
  real(wp) :: rpm, omega, alpha
  real(wp) :: mass(mtg,mtg), gyro(mtg,mtg)
  real(wp) :: kbase(mtg,mtg), cbase(mtg,mtg)
  real(wp) :: kphys(mtg,mtg), cphys(mtg,mtg)
  complex(wp) :: wk(mtg,mtg), wc(mtg,mtg)
  character(len=*) :: errmsg
  intrinsic :: real
  ok=-1
  if(dm.ne.gdm .or. dm.gt.mtg) then
    errmsg='transient: inconsistent global matrix dimension'
    return
  endif
  if(.not.ieee_is_finite(alpha)) then
    errmsg='A07: angular acceleration must be finite'
    return
  endif
  if(alpha/=0._wp .and. (any(mg(1:dm,1:dm)/=0).or.any(mka(1:dm,1:dm)/=0))) then
    errmsg='A07 NOT_QUALIFIED: variable spin needs drive torque/tilt-work contract; use constant RPM'
    return
  endif
  call transient_check_bearing_range(rpm,errmsg,oki)
  if(oki.ne.0) return
  call prpkc(real(omega, lrk),dm,pp,wk,wc,0,errmsg,oki)
  if(oki.ne.0) return
  do j=1,dm
    do i=1,dm
      mass(i,j)=real(mm(i,j), wp)
      gyro(i,j)=real(mg(i,j), wp)
      kbase(i,j)=real(mk1(i,j), wp)+real(real(wk(i,j)), wp)
      cbase(i,j)=real(real(wc(i,j)), wp)
    enddo
  enddo
  call transient_compose_rotation(dm,mtg,omega,alpha,gyro,mka,kbase,cbase,kphys,cphys)
  ok=0
  return
end subroutine transient_matrix_update
