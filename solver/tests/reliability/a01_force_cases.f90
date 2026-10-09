! Independent kinematic oracle: differentiate the position of an eccentric mass.
! This program calls the production force assembly and speed-profile routines.
program a01_force_cases
  use rd_kinds, only: wp,lrk
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use com_sec, only: nt,y
  use com_unb1, only: nb,ndd,mu,ed,tpf
  use com_mfa, only: au
  use com_trnctl, only: trn_enabled,trn_model,trn_speed_kind,trn_nprof
  use com_trnprof, only: trn_ptime,trn_prpm
  use com_trntime, only: trn_tstart,trn_tend,trn_dt,trn_phase0
  implicit none
  real(wp), parameter :: pi=acos(-1._wp),u=0.003_wp
  real(wp) :: force(500),expected(2),theta,omega,alpha,phase,h,s,err,maxerr
  real(wp) :: values(2,-2:2),rpm,om,al,ph,t,dt,r0,r1,integ,maxphase
  complex(wp) :: phasor(2),want(2),cphase
  integer :: ip,ia,iw,iu,j,k,ok,failures,cases,kind,step
  character(len=99) :: msg
  failures=0;cases=0;maxerr=0._wp;maxphase=0._wp
  nt=2;y=0._lrk;y(2)=1._lrk
  nb=2;ndd=0._lrk;ndd(1)=1._lrk;ndd(2)=0._lrk
  mu=0._lrk;mu(1)=u;mu(2)=100._lrk;tpf=0;tpf(2)=1;ed=0._lrk
  do iu=1,2
    au='D';if(iu==2) au='R'
    do ip=0,4
      theta=real(ip,wp)*pi/2._wp
      if(ip==4) theta=0.371_wp
      ed(1)=theta
      if(iu==1) ed(1)=theta*180._wp/pi
      do ia=-1,1
        alpha=real(ia,wp)*23._wp
        do iw=-1,1
          omega=real(iw,wp)*73._wp;phase=0.319_wp
          force=0._wp
          call transient_unbalance_force(8,omega,alpha,phase,force,msg,ok)
          if(ok/=0) error stop 'A01 production force assembly failed'
          ! Five-point numerical second derivative of r_e(t), not the patch formula.
          h=0.01_wp/max(1._wp,abs(omega),sqrt(abs(alpha)))
          do j=-2,2
            s=phase+theta+omega*j*h+0.5_wp*alpha*(j*h)**2
            values(:,j)=u*[sin(s),cos(s)]
          end do
          expected=(values(:,2)-16*values(:,1)+30*values(:,0)-16*values(:,-1)+values(:,-2))/(12*h*h)
          if(omega==0._wp.and.alpha==0._wp) expected=0._wp
          err=maxval(abs(force(5:6)-expected))/max(u*(omega*omega+abs(alpha)),1.e-12_wp)
          maxerr=max(maxerr,err);cases=cases+1
          if(err>3.e-6_wp) failures=failures+1
          if(any(force(1:4)/=0._wp).or.any(force(7:8)/=0._wp)) failures=failures+1
          if(.not.all(ieee_is_finite(force))) failures=failures+1
        end do
      end do
      ! DFT of production force, including arbitrary global and local phases.
      omega=73._wp;alpha=0._wp;phasor=cmplx(0._wp,0._wp,wp)
      do j=0,127
        phase=0.319_wp+2*pi*j/128
        force=0._wp
        call transient_unbalance_force(8,omega,alpha,phase,force,msg,ok)
        cphase=exp(cmplx(0._wp,-2*pi*j/128,wp))
        phasor=phasor+2._wp/128*force(5:6)*cphase
      end do
      cphase=u*omega*omega*exp(cmplx(0._wp,theta+0.319_wp,wp))
      want=[cmplx(0._wp,-1._wp,wp)*cphase,cphase]
      if(maxval(abs(phasor-want))>1.e-12_wp*abs(cphase)) failures=failures+1
    end do
  end do
  ! Exact quadrant counterexamples at zero speed: pure tangential force.
  au='R';phase=0._wp;omega=0._wp;alpha=2._wp
  do ip=0,3
    ed(1)=ip*pi/2;force=0._wp
    call transient_unbalance_force(8,omega,alpha,phase,force,msg,ok)
    select case(ip)
    case(0);expected=[-2*u,0._wp]
    case(1);expected=[0._wp,2*u]
    case(2);expected=[2*u,0._wp]
    case(3);expected=[0._wp,-2*u]
    end select
    if(maxval(abs(force(5:6)-expected))>1.e-14_wp) failures=failures+1
  end do
  ! Production profile preprocessing + state; integral independently summed.
  do kind=1,3
    call transient_reset()
    trn_enabled=.true.;trn_model=4;trn_speed_kind=kind
    trn_tstart=1.2_wp;trn_tend=2.6_wp;trn_dt=0.001_wp;trn_phase0=0.317_wp
    trn_nprof=3;trn_ptime(1:3)=[1.2_wp,1.7_wp,2.6_wp]
    trn_prpm(1:3)=[300._wp,1200._wp,450._wp]
    if(kind==1) trn_model=1
    if(kind==2) then
      trn_nprof=2;trn_ptime(2)=trn_tend
    end if
    call transient_prepare_profile(msg,ok)
    if(ok/=0) error stop 'A01 prepare speed profile'
    do step=0,28
      t=trn_tstart+step*0.05_wp
      call transient_speed_state(t,rpm,om,al,ph,msg,ok)
      if(ok/=0) error stop 'A01 speed state'
      integ=trn_phase0
      if(kind==1) then
        integ=integ+trn_prpm(1)*pi/30*(t-trn_tstart)
      else
        do k=1,trn_nprof-1
          dt=max(0._wp,min(t,trn_ptime(k+1))-trn_ptime(k))
          r0=trn_prpm(k)
          r1=r0+(trn_prpm(k+1)-r0)*dt/(trn_ptime(k+1)-trn_ptime(k))
          integ=integ+0.5_wp*(r0+r1)*dt*pi/30
        end do
      end if
      maxphase=max(maxphase,abs(ph-integ))
      if(abs(ph-integ)>1.e-12_wp) failures=failures+1
      if(abs(om-rpm*pi/30)>1.e-12_wp) failures=failures+1
    end do
  end do
  print '(a,i0)', 'KINEMATIC_CASES=',cases
  print '(a,es24.16)', 'MAX_FIVE_POINT_FORCE_ERROR=',maxerr
  print '(a,es24.16)', 'MAX_INTEGRATED_PHASE_ERROR=',maxphase
  print '(a,i0)', 'FAILED_CHECKS=',failures
  if(failures/=0) error stop 'A01 force/phase contract FAIL'
  print '(a)', 'A01_FORCE_PHASE: PASS'
end program a01_force_cases
