program support_records
  use rd_kinds, only: lrk
  use com_ymc, only: nbrg
  use com_sp1, only: ns,bn
  use com_sp2, only: sup,sps
  implicit none
  integer :: iu,ios,ok,variant,j
  logical :: found
  character(len=512) :: line
  character(len=99) :: msg
  nbrg=2
  do variant=0,1
    open(newunit=iu,status='scratch',form='formatted')
    if(variant==1) write(iu,'(a)') ''
    write(iu,'(a)') 'SUPPORT SCALE'
    write(iu,'(a)') '2         2.5'
    write(iu,'(a)') ''
    write(iu,'(a)') 'BEANBR    KXX       KXZ       KZZ       KZX       CXX       CXZ       CZZ       CZX       MASS'
    do j=1,2
      write(iu,'(i10,9es10.3)') j,1._lrk,2._lrk,4._lrk,3._lrk,5._lrk,6._lrk,8._lrk,7._lrk,9._lrk
    enddo
    write(iu,'(a)') 'FOUNDATION'
    rewind(iu)
    call input_record(iu,-1,line,ios)
    call support_read_block(iu,.true.,found,msg,ok)
    call check(ok==0.and.found,'fixed-width block')
    call check(ns==2.and.all(bn(1:2)==[1,2]),'IDs/count')
    call check(sps==2.5_lrk,'optional scale beyond column ten')
    call check(all(sup(1,:)==[(real(j,lrk),j=1,9)]),'canonical crossed-term order')
    call input_record(iu,0,line,ios)
    call check(ios==0.and.trim(line)=='FOUNDATION','following block retained')
    close(iu)
  enddo
  open(newunit=iu,status='scratch',form='formatted')
  write(iu,'(a)') ''
  write(iu,'(a)') 'FOUNDATION'
  write(iu,'(a)') 'ACTIVE YES'
  rewind(iu)
  call input_record(iu,-1,line,ios)
  call support_read_block(iu,.false.,found,msg,ok)
  call check(ok==0.and..not.found,'optional SUPPORT absent')
  call input_record(iu,0,line,ios)
  call check(ios==0.and.trim(line)=='FOUNDATION','pending header returned once')
  call input_record(iu,0,line,ios)
  call check(ios==0.and.trim(line)=='ACTIVE YES','pending record does not consume next line')
  close(iu)
  open(newunit=iu,status='scratch',form='formatted')
  write(iu,'(a)') 'SUPPORT'
  write(iu,'(a)') '2 INVALID'
  rewind(iu)
  call input_record(iu,-1,line,ios)
  call support_read_block(iu,.true.,found,msg,ok)
  call check(ok/=0.and.index(msg,'count/scale')>0,'invalid explicit scale rejected')
  close(iu)
  open(newunit=iu,status='scratch',form='formatted')
  write(iu,'(a)') 'SUPPORT'
  write(iu,'(a)') '2'
  write(iu,'(a)') 'BEANBR'
  rewind(iu)
  call input_record(iu,-1,line,ios)
  call support_read_block(iu,.true.,found,msg,ok)
  call check(ok/=0.and.index(msg,'row 1')>0,'truncated support has contextual error')
  close(iu)
  print '(a)', 'PASS IN-03: 15 native record/field assertions'
contains
  subroutine check(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition) then
      print '(a,a,a,a)', 'FAIL ',label,': ',trim(msg)
      stop 1
    endif
  end subroutine
end program
