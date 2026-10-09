! Synchronous lateral orbit reconstructed from the complete physical phasor.
! -t is periodic steady state; TRUE_TRANSIENT remains a separate integrator.
subroutine resp_t(pdm,pp,pv,shp,std,plt,errmsg,ok)
  use rd_textfun, only: ciff, femsgf, fomsgf
  use com_mdd, only: porb, rorb, rang
  use com_sec, only: y, nt
  use com_unb, only: nini_r, nfin_r, dw_r
  use com_unb1, only: ndd, tpf, nb
  use rd_kinds, only: lrk, wp
  use rd_harmonic_response, only: harmonic_response_point, harmonic_ld
  implicit none
  integer :: pdm,pp,pv,ok
  character(len=99) :: errmsg
  logical :: shp,std,plt
  integer, parameter :: mts=999,mxb=99,mxd=99,npo=50,mtr=1000
  integer :: i,j,k,l,m,o,h,nr,no,oki,ddm,dm,fx,ifidxof,foundation_ndof_f
  integer :: pdd(mxd),prs(mts)
  real(lrk) :: ndr,rad,rpm,pi2,rpif,rpm2radf,orientation
  real(lrk) :: t(npo),u(mts,mtr,npo),w(mts,mtr,npo),rpg(mtr),py(mts)
  complex(wp) :: rsp(harmonic_ld,1),time_phase
  character(len=2) :: di(mts,mtr)
  character(len=2), parameter :: dr(2)=(/'FW','BW'/)
  character(len=6), parameter :: nmm='resp_t'

  ok=-1
  errmsg=''
  if(dw_r<=0._lrk) then
    errmsg=femsgf(99,nmm,6,4,0)
    return
  end if
  if(nfin_r-nini_r<=0._lrk) then
    errmsg=femsgf(99,nmm,6,5,0)
    return
  end if

  ! Dimensions come from physical assembly, without reading/writing com_epm.
  ddm=pdm
  if(ddm<2.or.ddm>harmonic_ld.or.mod(ddm,2)/=0) then
    errmsg='resp_t: invalid assembled state dimension'
    return
  end if
  fx=1
  if(pv/=0) fx=0

  ! Preserve TIMSPD precedence and the historical sweep selection.
  if(rorb>0._lrk) then
    rpm=rorb
    ndr=1._lrk
    nr=1
  else
    ndr=dw_r
    rpm=nini_r
    if(rpm<=0._lrk) rpm=ndr
    nr=int((nfin_r-rpm)/ndr)+1
    if(nr<1) nr=1
  end if
  if(nr>mtr) then
    errmsg=fomsgf(99,nmm,4,'mtr',0)
    return
  end if

  call inddbl(y,ndd,pdd,nb,nt,mxb,mxd,mts,errmsg,oki)
  if(oki<0) return
  no=0
  do i=1,nb
    if(tpf(i)==0) then
      no=1
      exit
    end if
  end do
  if(no==0) then
    errmsg=fomsgf(99,nmm,18,' ',0)
    return
  end if

  if(.not.shp) then
    no=1
    py(no)=porb
    call indorb(y,py,prs,py,no,nt,mts,mts,errmsg,oki)
    if(oki<0) return
    if(porb<0._lrk) then
      i=nint(abs(porb))
      if(pp<=0.or.i<1.or.i>pp) then
        errmsg=femsgf(99,nmm,6,8,0)
        return
      end if
      py(no)=porb
    end if
  else
    no=nt
    do k=1,no
      py(k)=y(k)
      prs(k)=k
    end do
  end if

  pi2=2*rpif()
  do i=1,npo
    t(i)=pi2*(i-1)/(npo-1)
  end do
  dm=ddm/2-2*pp-foundation_ndof_f()
  call progress_begin('TIME_HARMONIC_RESPONSE',nr,&
    'complete physical synchronous harmonic response')

  do k=1,nr
    call progress_update('TIME_HARMONIC_RESPONSE',k,nr,rpm,'RPM')
    rad=rpm2radf(rpm)
    call harmonic_response_point(ddm,pp,fx,rpm,rad,pdd,rsp,errmsg,oki)
    if(oki/=0) then
      call progress_end('TIME_HARMONIC_RESPONSE','FAILED')
      return
    end if

    ! No foundation file is opened here. -f owns foundation_response.csv,
    ! so adding -t cannot replace/truncate its sweep in a combined run.
    do o=1,no
      if(py(o)>=0._lrk) then
        h=prs(o)
        l=ifidxof(h,1)
      else
        if(pp==0) then
          errmsg=femsgf(99,nmm,6,8,0)
          call progress_end('TIME_HARMONIC_RESPONSE','FAILED')
          return
        end if
        l=dm+(nint(abs(py(o)))-1)*2+1
      end if
      m=l+1
      if(l<1.or.m>ddm/2) then
        errmsg='resp_t: orbit position outside physical DOFs'
        call progress_end('TIME_HARMONIC_RESPONSE','FAILED')
        return
      end if
      do j=1,npo
        ! q(theta)=Re(qhat*exp(+i theta)); force phase is already in qhat.
        ! TANGLE is only used geometrically by the output projection.
        time_phase=exp(cmplx(0._wp,real(t(j),wp),kind=wp))
        u(o,k,j)=real(rsp(l,1)*time_phase,lrk)
        w(o,k,j)=real(rsp(m,1)*time_phase,lrk)
      end do
      ! Native FW is positive x increment from the +z axis:
      ! x=sin(theta), z=cos(theta) gives a positive signed expression.
      orientation=u(o,k,2)*w(o,k,1)-u(o,k,1)*w(o,k,2)
      di(o,k)=ciff(2,orientation>0._lrk,dr(1),dr(2))
    end do
    rpg(k)=rpm
    rpm=rpm+ndr
  end do

  call progress_stage('TIME_HARMONIC_RESPONSE','write physical harmonic orbit output')
  ! nmd=0 is the output contract for a complete physical-space response.
  ! NBRMOD remains accepted input, but cannot truncate this solution.
  call s_resp_t(shp,no,py,rpg,u,w,di,nr,npo,0,&
    mts,mtr,rang,std,plt,errmsg,ok)
  if(ok==0) then
    call progress_end('TIME_HARMONIC_RESPONSE','OK')
  else
    call progress_end('TIME_HARMONIC_RESPONSE','FAILED')
  end if
end subroutine resp_t
