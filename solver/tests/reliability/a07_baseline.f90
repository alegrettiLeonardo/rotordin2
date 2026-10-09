! Executable before-fix control: the old update substitutes G for K_alpha.
program a07_baseline
  use rd_kinds, only: wp
  use com_mat, only: mm, mg, dm
  use com_mtk, only: mk1
  use com_knd, only: cknd
  implicit none
  real(wp) :: mass(500,500), gyro(500,500), kb(500,500), cb(500,500)
  real(wp) :: k(500,500), c(500,500), error
  integer :: ok
  character(200) :: msg
  dm=4; mm=0; mg=0; mk1=0; cknd='1'
  mm(3,3)=1; mm(4,4)=1
  mg(3,4)=-2; mg(4,3)=2
  call transient_matrix_update(dm,0,0._wp,0._wp,3._wp,mass,gyro,kb,cb,k,c,msg,ok)
  if (ok/=0) error stop 'before-fix control must execute old update'
  error=abs(k(3,4)) ! no canonical alpha term in this equation
  print '(a,es24.16)', 'PREPATCH_SPURIOUS_K_34=',k(3,4)
  print '(a,es24.16)', 'EXPECTED_CANONICAL_K_34=',0._wp
  if (abs(error-6._wp)>1e-14_wp) error stop 'before-fix failure not reproduced'
  print '(a)', 'PREPATCH_A07_COUNTEREXAMPLE=FAIL (expected and reproduced)'
end program

subroutine prpkc(omega,n,pp,k,c,flag,msg,ok)
  use rd_kinds, only: wp
  implicit none
  real(wp) :: omega
  integer :: n,pp,flag,ok
  complex(wp) :: k(500,500),c(500,500)
  character(*) :: msg
  k=0; c=0; ok=0; msg=''
end subroutine
