! Compara a tabela de velocidades críticas com a referência congelada anterior.
program compare_results
  use, intrinsic :: iso_fortran_env, only: real64, error_unit
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer :: u, v, ios, n, i, count, words, j
  real(real64) :: rtol, atol, x(3), delta, max_delta
  real(real64), allocatable :: expected(:,:)
  character(4096) :: ref, actual, line
  logical :: found, started, inword
  if (command_argument_count() /= 2) error stop 'usage: compare_results reference stdout'
  call get_command_argument(1, ref)
  call get_command_argument(2, actual)
  open(newunit=u,file=trim(ref),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 'cannot open reference'
  read(u,*,iostat=ios) n, rtol, atol
  if (ios /= 0) error stop 'invalid reference header'
  if (n < 1 .or. n > 10000 .or. rtol < 0 .or. atol < 0) error stop 'invalid reference size/tolerance'
  allocate(expected(3,n))
  do i=1,n
    read(u,*,iostat=ios) expected(:,i)
    if (ios /= 0) error stop 'missing reference row'
  end do
  close(u)
  if (.not.all(ieee_is_finite(expected))) error stop 'nonfinite reference'
  open(newunit=v,file=trim(actual),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 'cannot open stdout'
  found=.false.; started=.false.; count=0; max_delta=0
  do
    read(v,'(a)',iostat=ios) line
    if (ios /= 0) exit
    if (.not.found) then
      if (index(line,'Critical Speeds (rpm)') > 0) found=.true.
      cycle
    end if
    if (len_trim(line) == 0) then
      if (started) exit
      cycle
    end if
    read(line,*,iostat=ios) x
    if (ios /= 0) then
      if (started) error stop 'invalid numeric row in output'
      cycle
    end if
    words=0; inword=.false.
    do j=1,len_trim(line)
      if (line(j:j)==' ' .or. iachar(line(j:j))==9) then
        inword=.false.
      else if (.not.inword) then
        words=words+1; inword=.true.
      end if
    end do
    if (words /= 3) error stop 'unexpected column count'
    started=.true.; count=count+1
    if (count > n) error stop 'extra critical-speed row'
    if (.not.all(ieee_is_finite(x))) error stop 'nonfinite result'
    do j=1,3
      delta=abs(x(j)-expected(j,count)); max_delta=max(max_delta,delta)
      if (delta > max(atol,rtol*max(abs(x(j)),abs(expected(j,count))))) then
        write(error_unit,*) 'FAIL row/column=',count,j,' got=',x(j),' expected=',expected(j,count)
        error stop 1
      end if
    end do
  end do
  close(v)
  if (.not.found .or. count /= n) error stop 'critical-speed table missing or truncated'
  write(*,'(a,i0,a,es12.4)') 'NUMERIC_REGRESSION: PASS; values=',3*n,'; max_delta_rpm=',max_delta
end program
