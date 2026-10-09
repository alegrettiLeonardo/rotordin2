! Fit the 49 unique orbit samples to a complex first harmonic. The duplicated
! endpoint is excluded; sampled maxima are never used for phase acceptance.
program compare_harmonic
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: wp=real64,maxb=2048,maxs=1000
  real(wp), parameter :: pi=acos(-1._wp)
  complex(wp), parameter :: zi=(0._wp,1._wp)
  type :: orbit_set
    integer :: n=0
    real(wp) :: rpm(maxb)=0._wp,pos(maxb)=0._wp
    complex(wp) :: q(2,maxb)=0._wp
    character(len=2) :: whirl(maxb)=' '
  end type
  type(orbit_set) :: a,b
  character(len=1024) :: mode,path1,path2,arg
  real(wp) :: phase,delta,maxdelta,amp(4,maxs),ph(4,maxs),rp(maxs)
  complex(wp) :: expected(2),direct(4,maxs)
  integer :: i,j,k,ns,matches
  call get_command_argument(1,mode)
  call get_command_argument(2,path1)
  call get_command_argument(3,path2)
  call get_command_argument(4,arg)
  call read_orbits(trim(path1),a)
  call check_whirl(a)
  maxdelta=0._wp; matches=0
  select case(trim(mode))
  case('orbits')
    phase=0._wp
    if(len_trim(arg)>0) read(arg,*) phase
    phase=phase*pi/180._wp
    call read_orbits(trim(path2),b)
    call check_whirl(b)
    if(a%n/=b%n) error stop 'orbit count changed'
    do i=1,a%n
      if(abs(a%rpm(i)-b%rpm(i))>1.e-8_wp.or.abs(a%pos(i)-b%pos(i))>1.e-8_wp) &
        error stop 'orbit positions or speeds differ'
      expected=exp(zi*phase)*a%q(:,i)
      delta=maxval(abs(expected-b%q(:,i)))
      maxdelta=max(maxdelta,delta)
      if(any(abs(expected-b%q(:,i))>1.e-12_wp+1.e-6_wp*max(abs(expected),abs(b%q(:,i))))) then
        print '(a,es24.16e3)', 'ORBIT_PHASOR_MISMATCH=',delta
        error stop 'orbit phasor comparison failed'
      end if
      matches=matches+1
    end do
  case('direct')
    call read_direct(trim(path1),ns,rp,amp,ph)
    direct(:,1:ns)=amp(:,1:ns)*exp(zi*ph(:,1:ns))
    do i=1,a%n
      k=0
      if(abs(a%pos(i)-0.4125_wp)<1.e-8_wp.or.a%pos(i)<0._wp) k=1
      if(abs(a%pos(i)-0.8_wp)<1.e-8_wp) k=3
      if(k==0) cycle
      do j=1,ns
        if(abs(a%rpm(i)-rp(j))>1.e-7_wp) cycle
        expected=direct(k:k+1,j)
        delta=maxval(abs(expected-a%q(:,i)))
        maxdelta=max(maxdelta,delta)
        if(any(abs(expected-a%q(:,i))>1.e-12_wp+1.e-6_wp*max(abs(expected),abs(a%q(:,i))))) then
          print '(a,es24.16e3)', 'DIRECT_ORBIT_PHASOR_MISMATCH=',delta
          error stop 'direct/orbit phasor comparison failed'
        end if
        matches=matches+1
        exit
      end do
    end do
  case default
    error stop 'expected direct or orbits mode'
  end select
  if(matches<1) error stop 'no matching physical observations'
  print '(a,i0)', 'MATCHED_PHASOR_PAIRS=',matches
  print '(a,es24.16e3)', 'MAX_ABSOLUTE_PHASOR_DIFFERENCE_M=',maxdelta
  print '(a)', 'HARMONIC_COMPARISON: PASS; fitted phasors and native FW/BW convention'
contains
  subroutine read_orbits(path,s)
    character(len=*), intent(in) :: path
    type(orbit_set), intent(out) :: s
    integer :: u,ios,j,n,support
    logical :: inside
    character(len=4096) :: line
    character(len=2) :: direction
    real(wp) :: speed,position,x,z,theta
    s%n=0; inside=.false.; speed=-1._wp; position=0._wp; direction=' '
    open(newunit=u,file=path,status='old',action='read')
    do
      read(u,'(a)',iostat=ios) line
      if(ios/=0) exit
      if(index(line,'#BEGIN timeresp.out')==1) inside=.true.
      if(index(line,'#END timeresp.out')==1) inside=.false.
      if(.not.inside) cycle
      if(index(line,'speed =')>0.and.index(line,'(rpm)')>0) then
        read(line(16:33),*,iostat=ios) speed
        if(ios/=0) error stop 'cannot read orbit speed'
      end if
      if(index(line,'dir =')>0) then
        n=len_trim(line); direction=line(n-1:n)
        if(index(line,'supp')>0) then
          read(line(23:24),*,iostat=ios) support
          position=-real(support,wp)
        else
          read(line(23:40),*,iostat=ios) position
        end if
        if(ios/=0) error stop 'cannot read orbit location'
      end if
      if(index(line,'x (m)')>0.and.index(line,'z (m)')>0) then
        s%n=s%n+1
        if(s%n>maxb) error stop 'test orbit capacity exceeded'
        n=s%n; s%rpm(n)=speed; s%pos(n)=position; s%whirl(n)=direction; s%q(:,n)=0._wp
        do j=1,50
          read(u,*,iostat=ios) x,z
          if(ios/=0) error stop 'incomplete orbit samples'
          if(j==50) cycle
          theta=2*pi*(j-1)/49
          s%q(:,n)=s%q(:,n)+[x,z]*exp(-zi*theta)*2/49
        end do
      end if
    end do
    close(u)
    if(s%n==0) error stop 'missing timeresp orbit data'
  end subroutine

  subroutine check_whirl(s)
    type(orbit_set), intent(in) :: s
    integer :: i
    real(wp) :: signed
    character(len=2) :: expected
    do i=1,s%n
      ! x=sin(theta), z=cos(theta) must be FW in the native convention.
      signed=-aimag(s%q(1,i)*conjg(s%q(2,i)))
      expected='BW'
      if(signed>0._wp) expected='FW'
      if(expected/=s%whirl(i)) error stop 'native whirl direction disagrees with fitted phasor'
    end do
  end subroutine

  subroutine read_direct(path,n,rpm,amplitude,angle)
    character(len=*), intent(in) :: path
    integer, intent(out) :: n
    real(wp), intent(out) :: rpm(maxs),amplitude(4,maxs),angle(4,maxs)
    integer :: u,ios,kind,np
    logical :: inside
    real(wp) :: row(5)
    character(len=4096) :: line
    n=0; np=0; kind=0; inside=.false.
    open(newunit=u,file=path,status='old',action='read')
    do
      read(u,'(a)',iostat=ios) line
      if(ios/=0) exit
      if(index(line,'#BEGIN unblresp.out')==1) inside=.true.
      if(index(line,'#END unblresp.out')==1) inside=.false.
      if(.not.inside) cycle
      if(index(line,'Amplitude (rpm) x (m)')>0) kind=1
      if(index(line,'Phase (rpm) x (rad)')>0) kind=2
      if(kind==0) cycle
      read(line,*,iostat=ios) row
      if(ios/=0) cycle
      if(kind==1) then
        n=n+1
        if(n>maxs) error stop 'test speed capacity exceeded'
        rpm(n)=row(1); amplitude(:,n)=row(2:5)
      else
        np=np+1
        if(np>n) error stop 'too many phase speeds'
        if(abs(row(1)-rpm(np))>1.e-8_wp) error stop 'direct amplitude/phase speed mismatch'
        angle(:,np)=row(2:5)
      end if
    end do
    close(u)
    if(n==0.or.n/=np) error stop 'missing direct response amplitude or phase'
  end subroutine
end program compare_harmonic
