! A07 native production-matrix / declared-kinematics numerical harness.
! No actual machine actuator is inferred by these isolated controls.
program a07_native
  use rd_kinds, only: wp
  use shaft_timoshenko_cowper, only: timo_cowper_gyro,timo_cowper_angular_acceleration
  use com_mat, only: mm,mg,mka,dm
  use com_mtk, only: mk1
  use com_sec, only: n,y,nt
  use com_sea, only: rs,es,gs,dely,s,ie,ump
  use com_seg, only: gfc
  use com_dis, only: nd,pd
  use com_dsc, only: md,idx,idy
  use com_doff, only: off_d
  use com_dflexi, only: dmodel,dfdofx,dfdofz
  use com_dflexr, only: dkr
  use com_conc, only: nmic,psic,vlmc,ixic,iyic,izic
  use com_sp1, only: ns
  use com_ymc, only: nbrg
  use com_knd, only: cknd,supr
  use com_progress_cfg, only: pgon
  use com_trnctl, only: trn_speed_kind,trn_nprof
  use com_trnprof, only: trn_prpm
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan,ieee_positive_inf,ieee_negative_inf,ieee_is_finite
  implicit none
  character(99) :: message,arg,action
  integer :: j,ic,ok,pp,pdm,bad_kind,bad_index,checks=0,failures=0
  real(wp) :: length,outer,inner,young,shear,density,area,inertia,gfactor,phi,kappa
  real(wp) :: ge(8,8),ba(8,8),g0(500,500),b0(500,500),m0(500,500),k0(500,500)
  real(wp) :: mp(500,500),gp(500,500),kb(500,500),cb(500,500),kp(500,500),cp(500,500)
  real(wp) :: qrig(8),vrig(8),pi,omega0,alpha,step
  real(wp) :: bad_inputs(7),bad_values(3)
  call get_command_argument(1,action)
  pgon=.false.; pi=acos(-1._wp)
  if(trim(action)=='integrate') then
    call get_command_argument(2,arg); read(arg,*) omega0
    call get_command_argument(3,arg); read(arg,*) alpha
    call get_command_argument(4,arg); read(arg,*) step
    call integrate_disk(omega0,alpha,step)
    stop
  endif
  call foundation_reset()
  do ic=1,5
    select case(ic)
    case(1); length=0.25_wp; outer=0.05_wp; inner=0._wp; gfactor=1._wp
    case(2); length=1._wp; outer=0.04_wp; inner=0.01_wp; gfactor=0.4_wp
    case(3); length=0.1_wp; outer=0.1_wp; inner=0.03_wp; gfactor=1.7_wp
    case(4); length=0.4_wp; outer=0.08_wp; inner=0.06_wp; gfactor=0._wp
    case(5); length=1.e6_wp; outer=0.05_wp; inner=0._wp; gfactor=1._wp
    end select
    young=207e9_wp; shear=young/2.6_wp; density=7850._wp
    area=pi*(outer**2-inner**2)/4._wp
    inertia=pi*(outer**4-inner**4)/64._wp
    call timo_cowper_gyro(length,young,shear,density,area,inertia,gfactor,ge,phi,kappa,ok)
    call check(ok>0,'gyro valid properties')
    call timo_cowper_angular_acceleration(length,young,shear,density,area,inertia,gfactor,ba,phi,kappa,ok)
    call check(ok>0,'acceleration valid properties')
    call near(maxval(abs(ba-transpose(ba)-ge)),0._wp,2e-13_wp*max(1._wp,maxval(abs(ge))), &
      'independently integrated B-B^T=G')
    qrig=[0._wp,0._wp,0.03_wp,-0.02_wp,0.02_wp*length,0.03_wp*length,0.03_wp,-0.02_wp]
    vrig=[0._wp,0._wp,-0.04_wp,0.05_wp,-0.05_wp*length,-0.04_wp*length,-0.04_wp,0.05_wp]
    call near(dot_product(vrig,matmul(ba,qrig)), &
      2*density*inertia*length*gfactor*0.05_wp*0.03_wp, &
      2e-13_wp*max(1._wp,2*density*inertia*length), 'rigid shaft polar kinetic energy')
    print '(a,i0,8(1x,es24.16))','SHAFT ',ic,length,outer,inner,young,shear,density,gfactor,phi
    call dump('B',ba,8,8)
    call dump('G',ge,8,8)
  enddo
  call timo_cowper_angular_acceleration(0._wp,young,shear,density,area,inertia,1._wp,ba,phi,kappa,ok)
  call check(ok<0,'zero length rejected')
  bad_values=[ieee_value(0._wp,ieee_quiet_nan),ieee_value(0._wp,ieee_positive_inf), &
    ieee_value(0._wp,ieee_negative_inf)]
  do bad_kind=1,3
    do bad_index=1,7
      bad_inputs=[0.25_wp,young,shear,density,area,inertia,1._wp]
      bad_inputs(bad_index)=bad_values(bad_kind)
      call timo_cowper_angular_acceleration(bad_inputs(1),bad_inputs(2),bad_inputs(3), &
          bad_inputs(4),bad_inputs(5),bad_inputs(6),bad_inputs(7),ba,phi,kappa,ok)
      call check(ok<0.and.all(ieee_is_finite(ba)).and.all(ba==0._wp).and. &
          ieee_is_finite(phi).and.ieee_is_finite(kappa),'nonfinite shaft B input rejected without arithmetic')
    enddo
  enddo

  ! Production assembly: uniform shaft plus independently recoverable rigid,
  ! offset, flexible-disk and concentrated polar-inertia contributions.
  n=0; n(1)=1; nt=2; y=0; y(2)=0.3_wp; dely=0; dely(1)=0.3_wp
  s=pi*0.05_wp**2/4; ie=pi*0.05_wp**4/64
  es=young; gs=shear; rs=density; ump=0; gfc=1.2_wp
  nd=0; nmic=0; ns=0; nbrg=0; cknd='1'; supr='N'; dmodel=0
  call matrizes(pp,pdm,message,ok)
  call check(ok==0,'shaft-only production assembly')
  b0=mka; g0=mg; m0=mm; k0=mk1
  nd=1; pd(1)=0; md(1)=3; idx(1)=0.4_wp; idy(1)=0.6_wp; off_d(1)=0.07_wp
  call matrizes(pp,pdm,message,ok)
  call check(ok==0,'offset rigid disk production assembly')
  call near(mka(4,3)-b0(4,3),0.6_wp,2e-14_wp,'rigid disk B_psi_theta=Ip')
  b0(4,3)=b0(4,3)+0.6_wp
  call near(maxval(abs(mka-b0)),0._wp,2e-14_wp,'rigid disk has no spurious B entries')
  call near(mm(1,4)-m0(1,4),-3*0.07_wp,2e-14_wp,'offset mass convention preserved')
  call near(maxval(abs(mka-transpose(mka)-mg)),0._wp,2e-13_wp,'global rigid B skew equals G')
  dmodel(1)=1; dkr(1)=12._wp
  call matrizes(pp,pdm,message,ok)
  call check(ok==0 .and.dm==10,'flexible disk production assembly')
  call near(mka(dfdofz(1),dfdofx(1)),0.6_wp,2e-14_wp,'flexible disk B on own rotations')
  call near(mka(4,3),b0(4,3)-0.6_wp,2e-14_wp,'flexible disk not counted on shaft rotations')
  call near(maxval(abs(mka(1:dm,1:dm)-transpose(mka(1:dm,1:dm))-mg(1:dm,1:dm))), &
      0._wp,2e-13_wp,'global flexible B skew equals G')
  nd=0; nmic=1; psic(1)=y(2); vlmc(1)=1; ixic(1)=0.2_wp; izic(1)=0.2_wp; iyic(1)=0.3_wp
  call matrizes(pp,pdm,message,ok)
  call check(ok==0,'concentrated polar inertia assembly')
  call near(mka(8,7)-b0(8,7),0.3_wp,2e-14_wp,'concentrated polar B term')
  call near(maxval(abs(mka(1:dm,1:dm)-transpose(mka(1:dm,1:dm))-mg(1:dm,1:dm))), &
      0._wp,2e-13_wp,'global concentrated B skew equals G')

  ! Contract gates: variable spin is rejected before any step for active polar
  ! coupling, including a plateau at t_start followed by a later ramp.
  trn_speed_kind=2; trn_nprof=3; trn_prpm(1:3)=[100._wp,100._wp,200._wp]
  call transient_angular_acceleration_contract(message,ok)
  call check(ok<0.and.index(message,'A07 NOT_QUALIFIED')>0,'delayed ramp blocked before initial step')
  trn_prpm(1:3)=[200._wp,200._wp,100._wp]
  call transient_angular_acceleration_contract(message,ok)
  call check(ok<0,'deceleration blocked')
  trn_prpm(1:3)=100._wp
  call transient_angular_acceleration_contract(message,ok)
  call check(ok==0,'flat tabular profile retained')
  trn_speed_kind=1
  call transient_angular_acceleration_contract(message,ok)
  call check(ok==0,'constant speed retained')
  call transient_matrix_update(dm,0,100._wp,7._wp,0._wp,mp,gp,kb,cb,kp,cp,message,ok)
  call check(ok==0,'constant native physical matrix update')
  call near(maxval(abs(kp(1:dm,1:dm)-kb(1:dm,1:dm))),0._wp,0._wp,'alpha=0 exact K preservation')
  call near(maxval(abs(cp(1:dm,1:dm)-cb(1:dm,1:dm)-7*mg(1:dm,1:dm))),0._wp,0._wp, &
      'constant-speed gyro preservation')
  call transient_matrix_update(dm,0,100._wp,7._wp,2._wp,mp,gp,kb,cb,kp,cp,message,ok)
  call check(ok<0,'direct production ramp update blocked')
  call transient_matrix_update(dm,0,100._wp,7._wp,-2._wp,mp,gp,kb,cb,kp,cp,message,ok)
  call check(ok<0,'direct production coastdown update blocked')
  call transient_matrix_update(dm,0,100._wp,7._wp,ieee_value(0._wp,ieee_quiet_nan), &
      mp,gp,kb,cb,kp,cp,message,ok)
  call check(ok<0,'NaN acceleration rejected')
  mg=0; mka=0; trn_speed_kind=2; trn_prpm(1:3)=[0._wp,100._wp,0._wp]
  call transient_angular_acceleration_contract(message,ok)
  call check(ok==0,'zero-polar-coupling ramp contract retained')
  call transient_matrix_update(dm,0,100._wp,7._wp,2._wp,mp,gp,kb,cb,kp,cp,message,ok)
  call check(ok==0,'zero-polar-coupling ramp matrix retained')
  call zero_polar_ramps()
  call poles()
  print '(a,i0,a,i0)','A07_NATIVE_CHECKS=',checks,' FAILURES=',failures
  if(failures/=0) error stop 1
contains
  subroutine check(condition,label)
    logical :: condition
    character(*) :: label
    checks=checks+1
    if(.not.condition) then
      failures=failures+1
      print '(a,a)','FAIL: ',label
    endif
  end subroutine
  subroutine near(actual,expected,tolerance,label)
    real(wp) :: actual,expected,tolerance
    character(*) :: label
    call check(abs(actual-expected)<=tolerance,label)
    if(abs(actual-expected)>tolerance) print '(3es24.16)',actual,expected,tolerance
  end subroutine
  subroutine dump(label,a,ld,dim)
    character(*) :: label
    integer :: ld,dim,i
    real(wp) :: a(ld,ld)
    print '(a,1x,i0)',label,dim
    do i=1,dim
      print '(*(es24.16,1x))',a(i,1:dim)
    enddo
  end subroutine
  subroutine integrate_disk(om0,al,dt)
    real(wp), intent(in) :: om0,al,dt
    real(wp) :: m(2,2),g(2,2),b(2,2),k(2,2),c(2,2),kn(2,2),w(2,2),kbase(2,2),cbase(2,2)
    real(wp) :: q(2),v(2),a(2),qn(2),vn(2),an(2),rhs(2),f(2),t
    integer :: piv(2),i,nstep,rc
    m=0; m(1,1)=1; m(2,2)=1
    b=0; b(2,1)=1.6_wp
    g=0; g(1,2)=-1.6_wp; g(2,1)=1.6_wp
    kbase=0; cbase=0; f=0
    q=[0.001_wp,-0.002_wp]; v=[0.0003_wp,0.0004_wp]
    call transient_compose_rotation(2,2,om0,al,g,b,kbase,cbase,k,c)
    call transient_initial_acceleration(2,2,m,c,k,f,q,v,a,w,rhs,piv,message,rc)
    if(rc/=0) error stop 'disk initial acceleration'
    print '(7es25.16)',0._wp,q,v,a
    nstep=nint(2._wp/dt)
    do i=1,nstep
      t=i*dt
      call transient_compose_rotation(2,2,om0+al*t,al,g,b,kbase,cbase,k,c)
      call transient_newmark_factor(2,2,m,c,k,dt,0.25_wp,0.5_wp,kn,piv,message,rc)
      if(rc/=0) error stop 'disk factor'
      call transient_newmark_step(2,2,m,c,dt,0.25_wp,0.5_wp,kn,piv,f,q,v,a,qn,vn,an,rhs,message,rc)
      if(rc/=0) error stop 'disk integration'
      q=qn; v=vn; a=an
      print '(7es25.16)',t,q,v,a
    enddo
  end subroutine
  subroutine poles()
    real(wp) :: aa(4,4),wr(4),wi(4),vs(1,1),work(256),om,al
    integer :: iom,ial,info,sdim
    logical :: bwork(4),a07_select
    external :: a07_select
    do iom=-1,1
      om=3*iom
      do ial=-1,1
        al=2*ial
        aa=0; aa(1,3)=1; aa(2,4)=1
        aa(3,1)=-9; aa(4,2)=-25; aa(4,1)=-al*1.6_wp
        aa(3,4)=om*1.6_wp; aa(4,3)=-om*1.6_wp
        call dgees('N','N',a07_select,4,aa,4,sdim,wr,wi,vs,1,work,256,bwork,info)
        call check(info==0,'native frozen disk poles')
        print '(a,2es24.16)','POLES',om,al
        do info=1,4
          print '(2es24.16)',wr(info),wi(info)
        enddo
      enddo
    enddo
  end subroutine
  subroutine zero_polar_ramps()
    ! A purely translational two-DOF analytical control has no spin-inertia
    ! torque work. Exercise the real TRANSIENT_RUN path for both ramp signs.
    use com_dflexi, only: nshaftfd
    use com_trnctl, only: trn_gravity,trn_unbalance,trn_nforce,trn_init_kind,trn_nic,trn_monitor_dof,trn_stride
    use com_trnic, only: trn_icdof,trn_icq,trn_icv
    use com_trnprof, only: trn_ptime,trn_pphase
    use com_trntime, only: trn_tstart,trn_tend,trn_dt,trn_beta,trn_gamma,trn_phase0
    real(wp) :: metrics(8),truth
    integer :: counts(4),ramp,rc
    dm=2; nshaftfd=2; mm=0; mg=0; mka=0; mk1=0; cknd='0'
    mm(1,1)=1; mm(2,2)=1; mk1(1,1)=9; mk1(2,2)=25
    trn_gravity=.false.; trn_unbalance=.false.; trn_nforce=0
    trn_init_kind=2; trn_nic=1; trn_monitor_dof=1; trn_stride=1
    trn_icdof(1)=1; trn_icq(1)=0.001_wp; trn_icv(1)=0
    trn_tstart=0; trn_tend=0.1_wp; trn_dt=0.0001_wp
    trn_beta=.25_wp; trn_gamma=.5_wp; trn_phase0=0
    trn_speed_kind=2; trn_nprof=2; trn_ptime(1:2)=[0._wp,0.1_wp]; trn_pphase=0
    truth=0.001_wp*cos(0.3_wp)
    do ramp=1,2
      if(ramp==1) then
        trn_prpm(1:2)=[0._wp,1500._wp]
      else
        trn_prpm(1:2)=[1500._wp,0._wp]
      endif
      counts=0
      call transient_run(6,0,trn_dt,.false.,metrics,counts,message,rc)
      call check(rc==0,'pure translational production ramp integrates')
      if(rc/=0) print '(a)',trim(message)
      call near(metrics(5),truth,1e-10_wp,'translational ramp agrees with exact free oscillator')
    enddo
  end subroutine
end program

logical function a07_select(wr,wi)
  use rd_kinds, only: wp
  implicit none
  real(wp) :: wr,wi
  a07_select=.false.
end function
