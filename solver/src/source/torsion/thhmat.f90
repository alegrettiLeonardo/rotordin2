!> Torsional receptance in a complete or truncated undamped modal basis.
!> Physical damping is generally nonclassical: retain the full modal block.
!> See docs/qualification/A04_TORSIONAL_DAMPING.md.
subroutine thhmat(rad,reye,tmd,cfi,clam,m1,nmd,mdoff,ddm,mtg)
  use rd_kinds, only: wp
  use, intrinsic :: iso_fortran_env, only: error_unit
  implicit none
  integer :: nmd,mdoff,ddm,mtg,ok
  real(wp) :: rad,reye(mtg,mtg),tmd(mtg,mtg)
  complex(wp) :: cfi(mtg,mtg),clam(mtg,mtg),m1(mtg,mtg)
  character(len=99) :: errmsg
  call thhmat_checked(rad,reye,tmd,cfi,clam,m1,nmd,mdoff,ddm,mtg,errmsg,ok)
  if(ok/=0) then
    write(error_unit,'(a)') trim(errmsg)
    error stop 1
  end if
end subroutine thhmat

subroutine thhmat_checked(rad,reye,tmd,cfi,clam,m1,nmd,mdoff,ddm,mtg,errmsg,ok)
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer,intent(in) :: nmd,mdoff,ddm,mtg
  real(wp),intent(in) :: rad,reye(mtg,mtg),tmd(mtg,mtg)
  complex(wp),intent(in) :: cfi(mtg,mtg),clam(mtg,mtg)
  complex(wp),intent(out) :: m1(mtg,mtg)
  character(len=99),intent(out) :: errmsg
  integer,intent(out) :: ok
  complex(wp),allocatable :: z(:,:),lu(:,:),rhs(:,:),solution(:,:),res(:,:)
  integer,allocatable :: ipiv(:)
  integer :: nr,i,j,ii,jj,info
  real(wp) :: denom,eta,znorm,xnorm,bnorm,tol
  ok=-1;errmsg=' ';m1=(0._wp,0._wp)
  nr=nmd-mdoff
  if(ddm<1.or.ddm>mtg.or.mdoff<0.or.nmd>ddm.or.nr<1) then
    errmsg='A04 thhmat: invalid dimensions or modal range';return
  end if
  if(.not.ieee_is_finite(rad).or..not.all(ieee_is_finite(tmd(1:ddm,1:ddm))).or. &
    .not.all(ieee_is_finite(reye(1:ddm,1:ddm))).or. &
    .not.all(ieee_is_finite(real(cfi(1:ddm,1:nr),wp))).or. &
    .not.all(ieee_is_finite(aimag(cfi(1:ddm,1:nr)))).or. &
    .not.all(ieee_is_finite(real(clam(1:ddm,1:ddm),wp))).or. &
    .not.all(ieee_is_finite(aimag(clam(1:ddm,1:ddm))))) then
    errmsg='A04 thhmat: finite frequency, modal matrices and vectors required';return
  end if
  if(abs(rad)>sqrt(huge(1._wp))) then
    errmsg='A04 thhmat: frequency square overflows real64';return
  end if
  allocate(z(nr,nr),lu(nr,nr),rhs(nr,ddm),solution(nr,ddm),res(nr,ddm),ipiv(nr))
  do j=1,nr
    jj=j+mdoff
    do i=1,nr
      ii=i+mdoff
      z(i,j)=clam(ii,jj)-rad**2*reye(ii,jj)+cmplx(0._wp,rad*tmd(ii,jj),wp)
    end do
  end do
  if(.not.all(ieee_is_finite(real(z,wp))).or..not.all(ieee_is_finite(aimag(z)))) then
    errmsg='A04 thhmat: nonfinite modal dynamic stiffness';return
  end if
  ! Solve Z_modal * X = Phi_retained^T; never invert only its diagonal.
  ! CFI has already been shifted by mdoff by the production callers.
  rhs=transpose(cfi(1:ddm,1:nr));solution=rhs;lu=z
  call zgetrf(nr,nr,lu,nr,ipiv,info)
  if(info/=0) then
    write(errmsg,'(a,i0)') 'A04 thhmat: singular modal dynamic stiffness; LU info=',info
    return
  end if
  call zgetrs('N',nr,ddm,lu,nr,ipiv,solution,nr,info)
  if(info/=0) then
    write(errmsg,'(a,i0)') 'A04 thhmat: modal solve failed; LAPACK info=',info
    return
  end if
  if(.not.all(ieee_is_finite(real(solution,wp))).or..not.all(ieee_is_finite(aimag(solution)))) then
    errmsg='A04 thhmat: nonfinite modal response';return
  end if
  res=matmul(z,solution)-rhs
  znorm=maxval(sum(abs(z),dim=2));xnorm=maxval(sum(abs(solution),dim=2));bnorm=maxval(sum(abs(rhs),dim=2))
  denom=znorm*xnorm+bnorm
  eta=maxval(sum(abs(res),dim=2))/max(denom,tiny(1._wp))
  tol=1000._wp*epsilon(1._wp)*real(max(nr,ddm),wp)
  if(.not.ieee_is_finite(eta).or.eta>tol) then
    write(errmsg,'(a,es10.2,a,es10.2)') 'A04 thhmat: modal residual=',eta,' exceeds ',tol
    return
  end if
  m1(1:ddm,1:ddm)=matmul(cfi(1:ddm,1:nr),solution)
  if(.not.all(ieee_is_finite(real(m1(1:ddm,1:ddm),wp))).or. &
     .not.all(ieee_is_finite(aimag(m1(1:ddm,1:ddm))))) then
    errmsg='A04 thhmat: nonfinite physical receptance';m1=(0._wp,0._wp);return
  end if
  ok=0
end subroutine thhmat_checked
