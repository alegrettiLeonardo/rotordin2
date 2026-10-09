! Stream real production force values for execution of pinned ROSS methods.
program a01_force_samples
  use rd_kinds, only: wp,lrk
  use com_sec, only: nt,y
  use com_unb1, only: nb,ndd,mu,ed,tpf
  use com_mfa, only: au
  implicit none
  real(wp) :: f(500),t,om,al,ph,delta
  integer :: ok
  character(len=99) :: msg
  nt=1;y=0._lrk;nb=1;ndd=0._lrk;mu=0._lrk;mu(1)=0.003_lrk;tpf=0;au='R'
  do
    read(*,*,iostat=ok) t,om,al,ph,delta
    if(ok<0) exit
    if(ok/=0) error stop 'A01 sample input'
    ed(1)=delta;f=0._wp
    call transient_unbalance_force(4,om,al,ph,f,msg,ok)
    if(ok/=0) error stop 'A01 sample force'
    print '(2(es25.17,1x))',f(1:2)
  end do
end program a01_force_samples
