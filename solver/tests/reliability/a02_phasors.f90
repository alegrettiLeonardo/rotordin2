! Independent complex-kinematics, virtual-work and interpolation oracles.
program a02_phasors
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use com_sec, only: nt,y
  use com_sea, only: ie
  use com_sed, only: ds
  use com_sprat, only: crat
  use com_sprat2, only: gsst
  use com_eqvlen, only: tsl
  implicit none
  real(wp), parameter :: pi=acos(-1._wp)
  real(wp), parameter :: kt=1.e5_wp,jp=1.e-6_wp,gg=1.e11_wp,radius=(2*jp/pi)**.25_wp,tol=2.e-12_wp
  complex(wp) :: q(3),delta,torque,stress,expected,rot,ta,tb,force(3),fref(3),refdelta
  real(wp) :: ratios(4),diffs(4),ratio,angle,b(3),k3(3,3),j3(3,3),kint(3,3),mq(3,3),ml(3,3)
  real(wp) :: kq(3,3),nshape(3),x,weight,gp(3),gw(3),e1,e2
  integer :: i,j,k,ok,checks
  character(len=99) :: msg
  ratios=[0.5_wp,1._wp,2._wp,-2._wp]
  diffs=[0._wp,pi/2,pi,3*pi/2]
  checks=0
  do i=1,size(ratios)
    ratio=ratios(i)
    do j=1,size(diffs)
      q=(0._wp,0._wp)
      q(1)=0.001_wp
      q(2)=0.001_wp*exp(cmplx(0._wp,diffs(j),wp))
      expected=kt*ratio*(q(2)-q(1))
      call tqe_phasor(1,1._wp,gg,jp,radius,ratio,1._wp,q,delta,torque,stress,msg,ok)
      call require(ok==0,'two-node return: '//trim(msg))
      call nearc(torque,expected,'two-node phase/ratio torque')
      call nearc(stress,expected*radius/jp,'two-node nominal stress')
      call nearc(delta,ratio*(q(2)-q(1)),'two-node physical relative twist')
      rot=exp(cmplx(0._wp,0.731_wp,wp));q=q*rot
      call tqe_phasor(1,1._wp,gg,jp,radius,ratio,-1._wp,q,delta,torque,stress,msg,ok)
      call nearc(torque,expected*rot,'global phase covariance')
      do k=0,3
        angle=k*pi/2
        call nearr(real(torque*exp(cmplx(0._wp,angle,wp)),wp), &
          kt*ratio*real((q(2)-q(1))*exp(cmplx(0._wp,angle,wp)),wp),'temporal signed torque')
      end do
    end do
  end do
  q=[cmplx(0.001_wp,0._wp,wp),cmplx(-0.001_wp,0._wp,wp),cmplx(0._wp,0._wp,wp)]
  call tqe_phasor(1,1._wp,gg,jp,radius,1._wp,1._wp,q,delta,torque,stress,msg,ok)
  call nearr(abs(torque),200._wp,'mandatory 200 Nm counterexample')
  write(*,'(a,es24.16)') 'MANDATORY_COUNTEREXAMPLE_NM=',abs(torque)
  q=q*1.e-9_wp
  call tqe_phasor(1,1._wp,gg,jp,radius,1._wp,1._wp,q,delta,torque,stress,msg,ok)
  call nearr(abs(torque),2.e-7_wp,'no amplitude-dependent small-angle cutoff')
  q=cmplx(0.7_wp,-0.23_wp,wp)
  do i=1,2
    call tqe_phasor(i,1._wp,gg,jp,radius,-2._wp,1._wp,q,delta,torque,stress,msg,ok)
    call nearc(torque,cmplx(0._wp,0._wp,wp),'complex rigid-body twist')
  end do

  ! The native three-node stiffness is EXACTLY two linear half-elements.
  call tk3s(k3); call tj3s(j3)
  kint=0._wp
  do i=1,2
    b=0._wp;b(i)=-2._wp;b(i+1)=2._wp
    do j=1,3
      do k=1,3
        kint(j,k)=kint(j,k)+0.5_wp*b(j)*b(k)
      end do
    end do
  end do
  call require(maxval(abs(kint-k3))<tol,'piecewise B integral agrees with real tk3s')
  q=[cmplx(.001_wp,.003_wp,wp),cmplx(-.002_wp,.001_wp,wp),cmplx(.003_wp,-.002_wp,wp)]
  do i=1,size(ratios)
    ratio=ratios(i)
    call tqe_phasor(2,1._wp,gg,jp,radius,ratio,-.5_wp,q,delta,ta,stress,msg,ok)
    call nearc(ta,2*kt*ratio*(q(2)-q(1)),'three-node left half')
    call tqe_phasor(2,1._wp,gg,jp,radius,ratio,.5_wp,q,delta,tb,stress,msg,ok)
    call nearc(tb,2*kt*ratio*(q(3)-q(2)),'three-node right half')
    force=ratio*[-ta,ta-tb,tb]
    fref=kt*ratio**2*matmul(k3,q)
    do j=1,3
      call nearc(force(j),fref(j),'generalized nodal torque and virtual work')
    end do
    call nearc(sum(force),cmplx(0._wp,0._wp,wp),'internal generalized torque equilibrium')
    e1=.25_wp*real(dot_product(q,fref),wp)
    e2=.25_wp*(abs(ta)**2+abs(tb)**2)/(2*kt)
    call nearr(e1,e2,'mean elastic energy from recovered torques')
  end do
  ! Affine twist produces constant physical torque even in the native 3-node K.
  q=[cmplx(0._wp,.001_wp,wp),cmplx(.001_wp,.002_wp,wp),cmplx(.002_wp,.003_wp,wp)]
  call tqe_phasor(2,1._wp,gg,jp,radius,1._wp,-.5_wp,q,delta,ta,stress,msg,ok)
  call tqe_phasor(2,1._wp,gg,jp,radius,1._wp,.5_wp,q,delta,tb,stress,msg,ok)
  call nearc(ta,tb,'uniform-bar torque conservation')

  ! Independently integrate quadratic Lagrange shape functions with 3-point Gauss.
  gp=[-sqrt(3._wp/5),0._wp,sqrt(3._wp/5)];gw=[5._wp/9,8._wp/9,5._wp/9]
  mq=0._wp;kq=0._wp
  do i=1,3
    x=gp(i);weight=gw(i)/2
    nshape=[x*(x-1)/2,1-x*x,x*(x+1)/2]
    b=[2*x-1,-4*x,2*x+1]
    do j=1,3
      do k=1,3
        mq(j,k)=mq(j,k)+weight*nshape(j)*nshape(k)
        kq(j,k)=kq(j,k)+weight*b(j)*b(k)
      end do
    end do
  end do
  call require(maxval(abs(mq-j3))<tol,'native tj3 is the quadratic consistent mass')
  call require(maxval(abs(kq-k3))>1._wp,'quadratic B is inconsistent with native tk3')
  ml=reshape([2._wp,1._wp,0._wp,1._wp,4._wp,1._wp,0._wp,1._wp,2._wp],[3,3])/12
  call require(maxval(abs(ml-j3))>.19_wp,'piecewise-linear B/J interpolation mismatch is real')
  write(*,'(a,es24.16)') 'THREE_NODE_K_QUADRATIC_MISMATCH_MAX=',maxval(abs(kq-k3))
  write(*,'(a,es24.16)') 'THREE_NODE_J_LINEAR_MISMATCH_MAX=',maxval(abs(ml-j3))
  write(*,'(a)') 'THREE_NODE_FULL_INTERPOLATION NOT_QUALIFIED'

  ! Native mapping, including existing equivalent length and one speed-ratio factor.
  nt=2;y(1:2)=[0._wp,1._wp];ie(1)=jp/2;ds(1:2)=2*radius
  gsst(1)=gg;tsl(1)=.25_wp;crat(1)=-2._wp
  q=[cmplx(.001_wp,.002_wp,wp),cmplx(-.003_wp,.001_wp,wp),cmplx(0._wp,0._wp,wp)]
  call tdvtrst_c(1,1,3,q,1._wp,delta,torque,stress,msg,ok)
  call require(ok==0,'native complex recovery')
  call nearc(torque,kt/1.25_wp*(-2)*(q(2)-q(1)),'native compliance length and ratio')
  call tdvtrst_c(1,0,3,q,1._wp,delta,torque,stress,msg,ok)
  call require(ok<0 .and. abs(torque)==0._wp,'invalid division fails closed')
  call tqe_phasor(1,0._wp,gg,jp,radius,1._wp,1._wp,q,delta,torque,stress,msg,ok)
  call require(ok<0,'zero effective length rejected')
  call tqe_phasor(1,1._wp,gg,0._wp,radius,1._wp,1._wp,q,delta,torque,stress,msg,ok)
  call require(ok<0,'zero polar area moment rejected')
  q(1)=cmplx(ieee_value(1._wp,ieee_quiet_nan),0._wp,wp)
  call tqe_phasor(1,1._wp,gg,jp,radius,1._wp,1._wp,q,delta,torque,stress,msg,ok)
  call require(ok<0 .and. index(msg,'nonfinite')>0,'nonfinite phasor rejected')
  write(*,'(a,i0)') 'A02_PHASOR_ASSERTIONS_PASS=',checks
contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if (.not.condition) then
      write(*,'(a)') 'FAIL '//label
      error stop 1
    end if
    checks=checks+1
  end subroutine
  subroutine nearc(a,b,label)
    complex(wp),intent(in)::a,b
    character(len=*),intent(in)::label
    if(abs(a-b)>tol*max(1._wp,abs(b))) then
      write(*,'(a,4es24.16)') trim(label),a,b
      error stop 2
    end if
    checks=checks+1
  end subroutine
  subroutine nearr(a,b,label)
    real(wp),intent(in)::a,b
    character(len=*),intent(in)::label
    call nearc(cmplx(a,0._wp,wp),cmplx(b,0._wp,wp),label)
  end subroutine
end program
