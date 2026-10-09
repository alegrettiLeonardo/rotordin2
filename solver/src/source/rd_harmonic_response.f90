! One-speed lateral harmonic solve shared by frequency response and orbit.
! The augmented operator and LAPACK leading dimensions are deliberately
! unchanged from resp_fv. No modal basis or matrix inverse is involved.
module rd_harmonic_response
  use rd_kinds, only: lrk, wp
  use rd_textfun, only: cadjf, fomsgf
  use rd_response_quality, only: response_quality_t, response_capture, &
    response_condition, response_report
  use com_mfa, only: au
  use com_unb1, only: mu, ed, tpf, nb
  implicit none
  private
  integer, parameter, public :: harmonic_ld = 1000
  public :: harmonic_response_point
contains
  subroutine harmonic_response_point(ddm,pp,fx,rpm,omega,pdd,rsp,errmsg,ok)
    integer, intent(inout) :: ddm
    integer, intent(in) :: pp,fx,pdd(:)
    real(lrk), intent(in) :: rpm,omega
    complex(wp), intent(out) :: rsp(harmonic_ld,1)
    character(len=99), intent(out) :: errmsg
    integer, intent(out) :: ok
    type(response_quality_t) :: audit_state
    complex(wp) :: hh(harmonic_ld,harmonic_ld)
    complex(wp), allocatable :: audit_force(:)
    complex(wp) :: pmn,xr,zr
    complex(wp), parameter :: c1p=(0._wp,1._wp),c1n=(0._wp,-1._wp)
    integer :: ipiv(harmonic_ld),info,oki,i,j,m,o,assembled_ddm
    integer :: ifidxof
    real(lrk) :: fps,toradf,riff
    character(len=1) :: crd
    character(len=3) :: cinfo
    logical :: isr

    ok=-1
    errmsg=''
    if(ddm<2.or.ddm>harmonic_ld.or.mod(ddm,2)/=0) then
      errmsg='harmonic_response: invalid assembled state dimension'
      return
    end if
    if(nb<0.or.nb>size(pdd)) then
      errmsg='harmonic_response: invalid unbalance position count'
      return
    end if
    crd=cadjf(1,au,1)
    isr=crd=='r'.or.crd=='R'
    assembled_ddm=ddm

    ! Preserve the six-step numerical chain and its original 1000 LDA/LDB.
    call mntmth(omega,ddm,pp,fx,hh,errmsg,oki)
    if(oki<0) return
    if(ddm/=assembled_ddm) then
      errmsg='harmonic_response: matrix dimension changed after assembly'
      return
    end if
    call response_capture(hh,ddm,audit_state,errmsg,oki)
    if(oki/=0) return
    call ZGETRF(ddm,ddm,hh,harmonic_ld,ipiv,info)
    if(info/=0) then
      write(cinfo,'(i3)') info
      errmsg=fomsgf(99,'resp_fv',23,cinfo,0)
      return
    end if
    call response_condition(hh,ddm,audit_state,errmsg,oki)
    if(oki/=0) return

    allocate(audit_force(ddm))
    call zervec_c(rsp,ddm,harmonic_ld)
    do i=1,nb
      ! KIND=0 retains the native convention and superposition. Other
      ! KINDs have the same capability as the former direct -f path.
      if(tpf(i)==0) then
        fps=riff(.not.isr,toradf(ed(i)),ed(i))
        xr=c1p*fps
        pmn=(mu(i)*omega**2)*exp(xr)
        m=pdd(i)
        j=ifidxof(m,1)
        o=j+1
        if(j<1.or.o>ddm/2) then
          errmsg='harmonic_response: unbalance index outside physical DOFs'
          return
        end if
        zr=c1n*pmn
        rsp(j,1)=rsp(j,1)+zr
        rsp(o,1)=rsp(o,1)+pmn
      end if
    end do

    audit_force=rsp(1:ddm,1)
    call ZGETRS('N',ddm,1,hh,harmonic_ld,ipiv,rsp,harmonic_ld,info)
    if(info/=0) then
      write(cinfo,'(i3)') info
      errmsg=fomsgf(99,'resp_fv',23,cinfo,0)
      return
    end if
    call response_report(real(rpm,wp),real(omega,wp),rsp(1:ddm,1), &
      audit_force,audit_state,errmsg,oki)
    if(oki/=0) return
    ok=0
  end subroutine harmonic_response_point
end module rd_harmonic_response
