! Native end-to-end comparator for the generic simple2b-sp fixture only.
program p1_compare_campbell
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer,parameter::wp=real64,np=50,nm=9,no=3,capacity=1024
  real(wp)::left(1+no+nm,np),right(1+no+nm,np),rl(no,nm),rr(no,nm)
  real(wp)::delta,max_frequency,max_root,allowed
  integer::i,j,nleft,nright,violations,nroot
  character(len=4096)::leftfile,rightfile
  character(len=32)::variant
  call get_command_argument(1,leftfile)
  if(leftfile=='--vectors')then
    if(command_argument_count()/=2)error stop 'usage: compare --vectors stdout'
    call get_command_argument(2,rightfile)
    call check_vector_oracle(rightfile)
    stop
  endif
  if(command_argument_count()/=3)error stop 'usage: compare left-stdout right-stdout baseline|current'
  call get_command_argument(1,leftfile);call get_command_argument(2,rightfile)
  call get_command_argument(3,variant)
  if(variant/='baseline'.and.variant/='current')error stop 'unknown comparison variant'
  call read_table(leftfile,'Natural frequencies (rpm) x (Hz)',left,nleft)
  call read_table(rightfile,'Natural frequencies (rpm) x (Hz)',right,nright)
  if(nleft/=np.or.nright/=np)error stop 'expected 50 presentation points'
  if(maxval(abs(left(1:1+no,:)-right(1:1+no,:)))>1.e-10_wp) &
    error stop 'different requested speed/excitation grids'
  max_frequency=0._wp;violations=0
  do i=1,np
    do j=2+no,1+no+nm
      delta=abs(left(j,i)-right(j,i));max_frequency=max(max_frequency,delta)
      allowed=0.01_wp+1.e-3_wp*max(abs(left(j,i)),abs(right(j,i)))
      if(delta>allowed)then
        violations=violations+1
        write(*,'(a,2i5,4es24.16)') 'FREQUENCY_DIFFERENCE ',i,j-1-no, &
          left(1,i),left(j,i),right(j,i),delta
      endif
    enddo
  enddo
  write(*,'(a,i0,a,es24.16)') 'PRESENTATION_COMPARE violations=',violations, &
    ' max_delta_Hz=',max_frequency
  if(variant=='baseline'.and.violations==0)error stop 'old interpolation defect not reproduced'
  if(variant=='current'.and.violations/=0)error stop 'same-speed presentation frequencies disagree'
  call read_table(leftfile,'Critical Speeds (rpm)',rl,nleft)
  call read_table(rightfile,'Critical Speeds (rpm)',rr,nright)
  if(nleft/=nm.or.nright/=nm)error stop 'critical-speed table truncated'
  if(any((rl==0._wp).neqv.(rr==0._wp)))error stop 'intersection count changed'
  if(count(rl(1,:)>0._wp)/=3)error stop 'generic fixture requires three 1X intersections'
  nroot=count(rl>0._wp)
  if(nroot/=15)error stop 'generic fixture requires fifteen intersections in total'
  max_root=0._wp
  do i=1,nm
    do j=1,no
      delta=abs(rl(j,i)-rr(j,i));max_root=max(max_root,delta)
      if(delta>1.e-3_wp+1.e-6_wp*max(abs(rl(j,i)),abs(rr(j,i)))) &
        error stop 'CPBSPD 5/25 intersection mismatch'
    enddo
  enddo
  write(*,'(a,i0,a,es24.16)') 'INTERSECTION_COMPARE count=',nroot,' max_delta_rpm=',max_root
  if(variant=='current')then
    call check_resolved(leftfile,left)
    call check_resolved(rightfile,right)
  endif
  write(*,'(a,a)') 'P1_CAMPBELL_COMPARE PASS ',trim(variant)
contains
  subroutine check_vector_oracle(path)
    character(len=*),intent(in)::path
    real(wp)::plot(4,500),roots(1,2),omega,b,frequency(2),expected_roots(2)
    real(wp)::max_frequency_error,max_root_error,quadratic,discriminant
    integer::nrows,nroots,j
    call read_table(path,'Natural frequencies (rpm) x (Hz)',plot,nrows)
    if(nrows/=50.and.nrows/=500)error stop 'unexpected vector presentation count'
    max_frequency_error=0._wp
    do j=1,nrows
      omega=plot(1,j)*acos(-1._wp)/30._wp
      ! M=diag(1,2), K=diag(4,18), D=Omega*[0,.15;-.15,0].
      ! det(K-w^2*M+i*w*D)=2*w^4-(26+.15^2*Omega^2)*w^2+72.
      b=26._wp+0.15_wp**2*omega**2
      discriminant=sqrt(b*b-576._wp)
      frequency=sqrt([(b-discriminant)/4._wp,(b+discriminant)/4._wp])/(2._wp*acos(-1._wp))
      max_frequency_error=max(max_frequency_error,maxval(abs(frequency-plot(3:4,j))))
    enddo
    if(max_frequency_error>1.e-6_wp)error stop 'vector plot differs from independent polynomial oracle'
    call read_table(path,'Critical Speeds (rpm)',roots,nroots)
    if(nroots/=2)error stop 'two vector 1X intersections expected'
    quadratic=2._wp-0.15_wp**2
    discriminant=sqrt(26._wp**2-4._wp*quadratic*72._wp)
    expected_roots=30._wp*sqrt([(26._wp-discriminant)/(2._wp*quadratic), &
      (26._wp+discriminant)/(2._wp*quadratic)])/acos(-1._wp)
    max_root_error=maxval(abs(roots(1,:)-expected_roots))
    if(any(abs(roots(1,:)-expected_roots)>1.e-3_wp+1.e-6_wp*expected_roots)) &
      error stop 'vector intersections differ from independent polynomial oracle'
    write(*,'(a,i0,2(a,es24.16))') 'VECTOR_POLYNOMIAL_ORACLE PASS points=',nrows, &
      ' max_delta_Hz=',max_frequency_error,' max_delta_rpm=',max_root_error
  end subroutine check_vector_oracle

  subroutine read_table(path,marker,values,nrows,complex_pairs)
    character(len=*),intent(in)::path,marker
    real(wp),intent(out)::values(:,:)
    integer,intent(out)::nrows
    logical,optional,intent(in)::complex_pairs
    character(len=4096)::line
    real(wp)::row(size(values,1))
    integer::u,ios,k
    logical::found,started
    open(newunit=u,file=trim(path),status='old',action='read',iostat=ios)
    if(ios/=0)error stop 'cannot open solver stdout'
    found=.false.;started=.false.;nrows=0;values=0._wp
    do
      read(u,'(a)',iostat=ios)line
      if(ios/=0)exit
      if(.not.found)then
        if(index(line,marker)>0)found=.true.
        cycle
      endif
      if(len_trim(line)==0)then
        if(started)exit
        cycle
      endif
      if(present(complex_pairs))then
        if(complex_pairs)then
          do k=1,len_trim(line)
            if(line(k:k)=='('.or.line(k:k)==')'.or.line(k:k)==',')line(k:k)=' '
          enddo
        endif
      endif
      read(line,*,iostat=ios)row
      if(ios/=0)then
        if(started)error stop 'invalid row in solver table'
        cycle
      endif
      nrows=nrows+1;started=.true.
      if(nrows>size(values,2))error stop 'table exceeds declared capacity'
      if(.not.all(ieee_is_finite(row)))error stop 'nonfinite solver table'
      values(:,nrows)=row
    enddo
    close(u)
    if(.not.found.or..not.started)error stop 'missing solver result table'
  end subroutine read_table

  subroutine check_resolved(path,plot)
    character(len=*),intent(in)::path
    real(wp),intent(in)::plot(:,:)
    real(wp)::accepted(capacity),display(np),eigenvalues(1+2*nm,capacity)
    real(wp)::rpm,omega,frequency,expected_rpm,max_value_error,max_speed_error
    integer::sample_of(np),u,ios,ns,nd,j,k,seq,sample,ne
    character(len=4096)::line
    character(len=80)::prefix,key,context,status
    ns=0;nd=0
    open(newunit=u,file=trim(path),status='old',action='read',iostat=ios)
    if(ios/=0)error stop 'cannot open audit output'
    do
      read(u,'(a)',iostat=ios)line
      if(ios/=0)exit
      if(index(line,'RD_AUDIT_V1 SPECTRUM CAMPBELL ')==1)then
        read(line,*,iostat=ios)prefix,key,context,rpm
        if(ios/=0)error stop 'malformed accepted spectrum'
        ns=ns+1
        if(ns>capacity)error stop 'audit sample capacity exceeded'
        if(ns>1)then
          if(rpm<=accepted(ns-1))error stop 'duplicate or backward accepted spectrum'
        endif
        accepted(ns)=rpm
      else if(index(line,'RD_AUDIT_V1 DISPLAY_POINT ')==1)then
        read(line,*,iostat=ios)prefix,key,seq,rpm,status,sample
        if(ios/=0)error stop 'malformed presentation provenance'
        nd=nd+1
        if(nd>np.or.seq/=nd.or.status/='RESOLVED')error stop 'invalid presentation provenance'
        display(nd)=rpm;sample_of(nd)=sample
      endif
    enddo
    close(u)
    if(nd/=np.or.ns<np)error stop 'every presentation speed must have a resolved spectrum'
    call read_table(path,'  Eigenvalues',eigenvalues,ne,.true.)
    if(ne/=ns)error stop 'accepted spectrum and published eigenvalue history differ'
    max_value_error=0._wp;max_speed_error=0._wp
    do j=1,np
      sample=sample_of(j)
      if(sample<1.or.sample>ns)error stop 'invalid accepted sample index'
      if(display(j)/=accepted(sample))error stop 'display speed absent from actual continuation'
      expected_rpm=6000._wp*real(j-1,wp)/real(np-1,wp)
      if(abs(display(j)-expected_rpm)>64._wp*epsilon(1._wp)*max(1._wp,expected_rpm)) &
        error stop 'unexpected resolved display grid'
      if(abs(display(j)-plot(1,j))>1.e-6_wp)error stop 'plot label differs from solved speed'
      omega=display(j)*acos(-1._wp)/30._wp
      max_speed_error=max(max_speed_error,abs(eigenvalues(1,sample)-omega))
      if(abs(eigenvalues(1,sample)-omega)>1.e-6_wp)error stop 'eigenvalue history speed mismatch'
      do k=1,nm
        frequency=abs(eigenvalues(1+2*k,sample))/(2._wp*acos(-1._wp))
        max_value_error=max(max_value_error,abs(frequency-plot(1+no+k,j)))
        ! Only the finite printed decimal precision of the two legacy tables
        ! is allowed here; this is tighter than the physical regression target.
        if(abs(frequency-plot(1+no+k,j))>1.e-6_wp) &
          error stop 'plot value is not the eigenfrequency at its accepted speed'
      enddo
    enddo
    write(*,'(a,i0,a,i0,2(a,es24.16))') 'RESOLVED_PROVENANCE display=',nd, &
      ' accepted=',ns,' max_print_delta_Hz=',max_value_error,' max_print_delta_rad_s=',max_speed_error
  end subroutine check_resolved
end program p1_compare_campbell
