! Numeric smoke tests for the LAPACK/BLAS 3.12.1 source-built backend.
! Not a complete LAPACK or rotordynamics validation suite.
module smoke_checks
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer, parameter :: dp=real64
  real(dp), parameter :: tol=1.0e-10_dp
contains
  subroutine check(label,error)
    character(*), intent(in) :: label
    real(dp), intent(in) :: error
    if (.not.ieee_is_finite(error) .or. error>tol) then
      write(*,'(a,1x,a,es15.6)') 'FAIL',label,error
      error stop 1
    endif
    write(*,'(a,1x,a,1x,es15.6)') 'PASS',label,error
  end subroutine
  subroutine status(label,info)
    character(*),intent(in)::label
    integer,intent(in)::info
    if(info/=0) then
      write(*,*) 'FAIL', label, ' INFO=',info
      error stop 1
    endif
  end subroutine
  logical function select_positive(wr,wi)
    real(dp),intent(in)::wr,wi
    select_positive=wr>1.0_dp
  end function
  function eye(n) result(a)
    integer,intent(in)::n
    real(dp)::a(n,n)
    integer::i
    a=0
    do i=1,n
      a(i,i)=1
    enddo
  end function
  subroutine test_blas()
    real(dp)::a(2,2),b(2,2),c(2,2)
    a=reshape([1.0_dp,2.0_dp,3.0_dp,4.0_dp],[2,2]);b=eye(2);c=0
    call dgemm('N','N',2,2,2,1.0_dp,a,2,b,2,0.0_dp,c,2)
    call check('DGEMM',maxval(abs(c-a)))
  end subroutine
  subroutine test_cholesky()
    real(dp)::a(2,2),original(2,2),l(2,2)
    integer::info
    a=reshape([4.0_dp,2.0_dp,2.0_dp,3.0_dp],[2,2]);original=a
    call dpotrf('L',2,a,2,info);call status('DPOTRF',info)
    l=a;l(1,2)=0
    call check('DPOTRF',maxval(abs(matmul(l,transpose(l))-original)))
    a=0;a(1,1)=-1;a(2,2)=1
    call dpotrf('L',2,a,2,info)
    if(info/=1) error stop 'DPOTRF negative-definite input not detected'
    call check('DPOTRF rejects invalid SPD',0.0_dp)
  end subroutine
  subroutine test_symmetric(n)
    integer,intent(in)::n
    real(dp)::a(n,n),original(n,n),w(n),work(max(1,64*n)),expected(n),res(n,n)
    integer::i,info
    character(40)::label
    a=2*eye(n)
    do i=1,n-1
      a(i,i+1)=-1;a(i+1,i)=-1
    enddo
    original=a
    call dsyev('V','L',n,a,n,w,work,size(work),info);call status('DSYEV',info)
    do i=1,n
      expected(i)=2-2*cos(real(i,dp)*acos(-1.0_dp)/real(n+1,dp))
      res(:,i)=matmul(original,a(:,i))-w(i)*a(:,i)
    enddo
    write(label,'(a,i0)') 'DSYEV n=',n
    call check(trim(label),max(maxval(abs(res)),maxval(abs(w-expected)), &
                               maxval(abs(matmul(transpose(a),a)-eye(n)))))
  end subroutine
  subroutine test_symmetric_generalized()
    real(dp)::a(2,2),b(2,2),aa(2,2),bb(2,2),w(2),work(128),res(2,2),expected(2)
    integer::info,i
    a=reshape([2.0_dp,1.0_dp,1.0_dp,2.0_dp],[2,2]);b=eye(2);b(1,1)=2
    aa=a;bb=b;expected=[(3-sqrt(3.0_dp))/2,(3+sqrt(3.0_dp))/2]
    call dsygv(1,'V','L',2,a,2,b,2,w,work,size(work),info);call status('DSYGV',info)
    do i=1,2
      res(:,i)=matmul(aa,a(:,i))-w(i)*matmul(bb,a(:,i))
    enddo
    call check('DSYGV',max(maxval(abs(res)),maxval(abs(w-expected)), &
                        maxval(abs(matmul(transpose(a),matmul(bb,a))-eye(2)))))
  end subroutine
  subroutine test_schur()
    real(dp)::a(3,3),aa(3,3),q(3,3),wr(3),wi(3),work(256),s,sep
    integer::info,sdim,m,iw(128)
    logical::bw(3),selection(3)
    a=0;a(1,2)=-2;a(2,1)=2;a(3,3)=5;aa=a
    call dgees('V','S',select_positive,3,a,3,sdim,wr,wi,q,3,work,size(work),bw,info)
    call status('DGEES',info)
    if(sdim/=1) error stop 'DGEES wrong selected subspace dimension'
    call check('DGEES sorted complex pair',max(maxval(abs(matmul(aa,q)-matmul(q,a))), &
                          maxval(abs(matmul(transpose(q),q)-eye(3))),abs(wr(1)-5)))
    selection=[.false.,.true.,.true.]
    call dtrsen('B','V',selection,3,a,3,q,3,wr,wi,m,s,sep,work,size(work),iw,size(iw),info)
    call status('DTRSEN',info)
    if(m/=2 .or. .not.ieee_is_finite(sep) .or. sep<=0) error stop 'DTRSEN subspace or separation failure'
    call check('DTRSEN reorder and conditions',max(maxval(abs(matmul(aa,q)-matmul(q,a))), &
                          maxval(abs(matmul(transpose(q),q)-eye(3))),maxval(abs(wr(1:2)))))
  end subroutine
  subroutine test_generalized()
    real(dp)::a(2,2),b(2,2),aa(2,2),bb(2,2),vl(2,2),vr(2,2),ar(2),ai(2),beta(2)
    real(dp)::ls(2),rs(2),abn,bbn,rce(2),rcv(2),work(256),res(2,2)
    integer::ilo,ihi,info,iw(32),i
    logical::bw(2)
    a=eye(2);a(2,2)=4;b=eye(2);b(1,1)=2;aa=a;bb=b
    call dggevx('B','V','V','B',2,a,2,b,2,ar,ai,beta,vl,2,vr,2,ilo,ihi, &
                ls,rs,abn,bbn,rce,rcv,work,size(work),iw,bw,info)
    call status('DGGEVX',info)
    do i=1,2
      res(:,i)=beta(i)*matmul(aa,vr(:,i))-ar(i)*matmul(bb,vr(:,i))
    enddo
    call check('DGGEVX',max(maxval(abs(res)),maxval(abs(ar/beta-[0.5_dp,4.0_dp])),maxval(abs(ai))))
  end subroutine
  subroutine test_svd(m,n)
    integer,intent(in)::m,n
    complex(dp)::a(m,n),aa(m,n),u(m,n),vt(n,n),work(1024),us(m,n),id(n,n)
    real(dp)::s(n),rwork(5*n)
    integer::i,j,info
    character(40)::label
    do j=1,n
      do i=1,m
        a(i,j)=cmplx(sin(real(i*j,dp)),cos(real(i+2*j,dp)),dp)
      enddo
    enddo
    aa=a
    call zgesvd('S','S',m,n,a,m,s,u,m,vt,n,work,size(work),rwork,info)
    call status('ZGESVD',info)
    do j=1,n
      us(:,j)=s(j)*u(:,j)
    enddo
    id=cmplx(eye(n),0.0_dp,dp)
    write(label,'(a,i0,a,i0)') 'ZGESVD ',m,'x',n
    call check(trim(label),max(maxval(abs(matmul(us,vt)-aa))/max(1.0_dp,maxval(abs(aa))), &
                              maxval(abs(matmul(transpose(conjg(u)),u)-id))))
  end subroutine
  subroutine test_lu_real()
    real(dp)::a(2,2),aa(2,2),b(2,1),bb(2,1)
    integer::ipiv(2),info
    a=reshape([4.0_dp,1.0_dp,2.0_dp,3.0_dp],[2,2]);aa=a
    b(:,1)=[2.0_dp,-5.0_dp];bb=b
    call dgetrf(2,2,a,2,ipiv,info);call status('DGETRF',info)
    call dgetrs('N',2,1,a,2,ipiv,b,2,info);call status('DGETRS',info)
    call check('DGETRF/DGETRS',maxval(abs(matmul(aa,b)-bb)))
  end subroutine
  subroutine test_lu_complex()
    complex(dp)::a(2,2),aa(2,2),b(2,1),bb(2,1)
    integer::ipiv(2),info
    a=reshape([cmplx(4,1,dp),cmplx(1,-1,dp),cmplx(2,2,dp),cmplx(3,-1,dp)],[2,2]);aa=a
    b(:,1)=[cmplx(2,1,dp),cmplx(-5,2,dp)];bb=b
    call zgetrf(2,2,a,2,ipiv,info);call status('ZGETRF',info)
    call zgetrs('N',2,1,a,2,ipiv,b,2,info);call status('ZGETRS',info)
    call check('ZGETRF/ZGETRS',maxval(abs(matmul(aa,b)-bb)))
  end subroutine
  subroutine test_complex_generalized()
    complex(dp)::a(2,2),b(2,2),aa(2,2),bb(2,2),alpha(2),beta(2),vl(2,2),vr(2,2),work(256),res(2,2)
    real(dp)::ls(2),rs(2),abn,bbn,rce(2),rcv(2),rw(32)
    integer::ilo,ihi,info,iw(32),i
    logical::bw(2)
    a=0;b=0;a(1,1)=cmplx(1,1,dp);a(2,2)=cmplx(4,-2,dp);b(1,1)=2;b(2,2)=1;aa=a;bb=b
    call zggevx('B','V','V','B',2,a,2,b,2,alpha,beta,vl,2,vr,2,ilo,ihi,ls,rs,abn,bbn, &
                rce,rcv,work,size(work),rw,iw,bw,info)
    call status('ZGGEVX',info)
    do i=1,2
      res(:,i)=beta(i)*matmul(aa,vr(:,i))-alpha(i)*matmul(bb,vr(:,i))
    enddo
    call check('ZGGEVX',max(maxval(abs(res)), &
      maxval(abs(alpha/beta-[cmplx(0.5_dp,0.5_dp,dp),cmplx(4,-2,dp)]))))
  end subroutine
  subroutine test_blas2()
    real(dp)::a(2,2),x(2),y(2)
    a=reshape([1.0_dp,2.0_dp,3.0_dp,4.0_dp],[2,2]);x=[2.0_dp,-1.0_dp];y=0
    call dgemv('N',2,2,1.0_dp,a,2,x,1,0.0_dp,y,1)
    call check('DGEMV',maxval(abs(y-matmul(a,x))))
  end subroutine
  subroutine test_safe_norm()
    real(dp)::x(2),n,err
    real(dp),external::dnrm2
    x=[3.0e200_dp,4.0e200_dp];n=dnrm2(2,x,1);err=abs(n/5.0e200_dp-1)
    x=[3.0e-200_dp,4.0e-200_dp];n=dnrm2(2,x,1);err=max(err,abs(n/5.0e-200_dp-1))
    call check('DNRM2 scaled extremes',err)
  end subroutine
end module

program linalg_smoke
  use smoke_checks
  implicit none
  if(storage_size(0)/=32 .or. storage_size(1.0_dp)/=64) error stop 'LP64/REAL64 ABI mismatch'
  call test_blas()
  call test_cholesky()
  call test_symmetric(2)
  call test_symmetric(80)
  call test_symmetric_generalized()
  call test_schur()
  call test_generalized()
  call test_svd(3,2)
  call test_svd(40,22)
  call test_lu_real()
  call test_lu_complex()
  call test_complex_generalized()
  call test_blas2()
  call test_safe_norm()
  print *, 'LINALG_SMOKE: 16 checks PASS; tolerance=',tol
end program
