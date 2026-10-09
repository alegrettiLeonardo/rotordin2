! Real production assembly, eigenproblem, FRF/periodic solver and text output.
! Independent analytic oracle is the uniform Saint-Venant shaft element.
program a02_native
  use rd_kinds, only: wp
  use com_sec, only: nt,nn,y,n
  use com_sea, only: rs,gs,ie,dely
  use com_sed, only: ds
  use com_eix, only: ps
  use com_eqvlen, only: tsl
  use com_couplings, only: ncplg,cplgid,cplgst,cplgin,cplgdp,cplgsr
  use com_conc, only: nmic
  use com_dis, only: nd
  use com_tman, only: ntbr
  use com_unb, only: nini_r,nfin_r,dw_r
  use com_unb0, only: np,pr,nm
  use com_unb1, only: nb,ndd,mu,ed,tpf
  use com_mdampso, only: mdoff
  use com_mdamps, only: ntdmp
  use com_thmfr, only: thfr
  use com_tpfrt, only: fprt,fprts
  use com_tmat, only: tj,tk,dm
  use com_tepm, only: rfi,rlam,ddm
  use com_tmdm, only: tmd
  use com_sta, only: stm
  implicit none
  real(wp), parameter :: pi=acos(-1._wp),kt=1.e5_wp,polar_mass=.1_wp,jp=1.e-6_wp
  real(wp), parameter :: gg=1.e11_wp,radius=(2*jp/pi)**.25_wp,torque_in=100._wp
  real(wp) :: ratio,phase,omega,delta_phase,diagonal,offdiag,mres,kres
  complex(wp) :: q1,q2,qout,p1,p2,tqhat,dtwist,sthat,detsys,phase0
#ifdef A02_CURRENT
  real(wp) :: reye(500,500)
  complex(wp) :: cfi(500,500),clam(500,500),hh(500,500),nativeq(2),natived,nativet,natives
#endif
  integer :: im,ok,pdm,i,j
  character(len=99) :: msg
  character(len=32) :: route,arg
  call get_command_argument(1,route)
  call get_command_argument(2,arg); read(arg,*) ratio
  call get_command_argument(3,arg); read(arg,*) delta_phase
  call get_command_argument(4,arg); read(arg,*) im
  stm="A02_NATIVE_QUALIFICATION";msg=""
  phase=.371_wp;delta_phase=delta_phase*pi/180
  nt=2;nn=1;y=0._wp;y(2)=1._wp;n=0._wp;n(1)=1._wp
  ps=0._wp;ps(1)=1._wp
  gs=gg;rs=polar_mass/jp;ie=jp/2;dely=1._wp;tsl=0._wp;ds=2*radius
  nmic=0;nd=0;ntbr=0
  ! Equivalent coupling reproduces the exact same uniform k/J and exposes
  ! the native reflected train ratio. This is an equivalent elastic element.
  ncplg=1;cplgid(1)=1;cplgst(1)=kt;cplgin(1)=polar_mass
  cplgdp(1)=0._wp;cplgsr(1)=ratio
  call tmatrices(im,pdm,msg,ok)
  if(ok<0) then
    write(*,'(a)') trim(msg);error stop 'native assembly failed'
  end if
  if(im==1) then
    mres=maxval(abs(tj(1:2,1:2)-ratio**2*polar_mass/6* &
        reshape([2._wp,1._wp,1._wp,2._wp],[2,2])))
    kres=maxval(abs(tk(1:2,1:2)-ratio**2*kt* &
        reshape([1._wp,-1._wp,-1._wp,1._wp],[2,2])))
    if(mres>2.e-13_wp .or. kres>2.e-8_wp) error stop 'native matrices differ from uniform-bar oracle'
    write(*,'(a,4es24.16)') 'NATIVE_J ',tj(1,1),tj(1,2),tj(2,1),tj(2,2)
    write(*,'(a,4es24.16)') 'NATIVE_K ',tk(1,1),tk(1,2),tk(2,1),tk(2,2)
  end if
  call tespmod(msg,ok)
  if(ok<0) then
    write(*,'(a)') trim(msg);error stop 'native eigenproblem failed'
  end if
  ntdmp=0;mdoff=0;call tmdamp()
  nb=2;ndd(1:2)=[0._wp,1._wp];mu(1)=ratio*torque_in;mu(2)=torque_in
  ed(1)=phase;ed(2)=phase+delta_phase;tpf(1:2)=4
  ! Right-end output only: native baseline fails for division zero at left.
  np=1;pr(1)=1._wp;nm=2*ddm
  omega=50._wp
  nini_r=omega*30/pi;nfin_r=60._wp*30/pi;dw_r=nfin_r-nini_r
  fprts=pi/(2*omega);fprt=3*fprts;thfr(1:2)=omega
  phase0=exp(cmplx(0._wp,phase,wp))
  write(*,'(a,a)') 'NATIVE_ROUTE=',trim(route)
  write(*,'(a,es24.16)') 'NATIVE_RATIO=',ratio
  if(im==1) then
    ! Independent direct 2x2 solution in the reflected coordinates.
    do i=1,2
      omega=50._wp+10*(i-1)
      diagonal=ratio**2*(kt-omega**2*polar_mass/3)
      offdiag=ratio**2*(-kt-omega**2*polar_mass/6)
      p1=ratio*torque_in*phase0;p2=ratio*torque_in*exp(cmplx(0._wp,phase+delta_phase,wp))
      detsys=(diagonal-offdiag)*(diagonal+offdiag)
      q1=(diagonal*p1-offdiag*p2)/detsys
      q2=(diagonal*p2-offdiag*p1)/detsys
      qout=ratio*q2
      if(index(route,"firstnode")>0) qout=q1
      dtwist=ratio*(q2-q1);tqhat=kt*dtwist;sthat=tqhat*radius/jp
      write(*,'(a,11es24.16)') 'ORACLE ',omega,qout,dtwist,tqhat,sthat,abs(tqhat),abs(sthat)
#ifdef A02_CURRENT
      reye=0._wp;clam=(0._wp,0._wp);cfi=(0._wp,0._wp)
      do j=1,2
        reye(j,j)=1._wp;clam(j,j)=rlam(j)
        cfi(1:2,j)=cmplx(rfi(1:2,j),0._wp,wp)
      end do
      call thhmat(omega,reye,tmd,cfi,clam,hh,2,0,2,500)
      nativeq=matmul(hh(1:2,1:2),[p1,p2])
      call tdvtrst_c(1,1,2,nativeq,1._wp,natived,nativet,natives,msg,ok)
      if(ok<0) error stop 'native complex effort recovery failed'
      if(index(route,'firstnode')>0) then
        write(*,'(a,9es24.16)') 'NATIVE_PHASOR ',omega,nativeq(1),natived,nativet,natives
      else
        write(*,'(a,9es24.16)') 'NATIVE_PHASOR ',omega,ratio*nativeq(2),natived,nativet,natives
      end if
#endif
      if(i==1) then
        do j=0,3
          phase0=exp(cmplx(0._wp,j*pi/2,wp))
          write(*,'(a,5es24.16)') 'TIME_ORACLE ',j*fprts,real(qout*phase0,wp), &
            real(dtwist*phase0,wp),real(tqhat*phase0,wp),real(sthat*phase0,wp)
        end do
        phase0=exp(cmplx(0._wp,phase,wp))
      end if
    end do
  end if
  if(trim(route)=='frequency') then
    call tresp_f(im,.true.,.false.,.true.,.false.,msg,ok)
  else if(trim(route)=='firstnode') then
    pr(1)=0._wp
    call tresp_f(im,.true.,.false.,.true.,.false.,msg,ok)
  else if(trim(route)=='periodic' .or. trim(route)=='periodic_firstnode') then
    if(index(route,'firstnode')>0) pr(1)=0._wp
    tpf(1:2)=2
    call tpefors(im,.true.,.true.,.false.,msg,ok)
  else
    error stop 'unknown route'
  end if
  write(*,'(a,i0,1x,a)') 'NATIVE_RESULT=',ok,trim(msg)
  if(im==2) then
#ifdef A02_CURRENT
    if(ok>=0 .or. index(msg,'A02 NOT_QUALIFIED')==0) error stop '3-node interpolation must fail closed'
#endif
  else
    if(ok<0) error stop 'native response failed'
  end if
end program
