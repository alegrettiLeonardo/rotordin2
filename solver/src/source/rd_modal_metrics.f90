! Audit F02/F03/F04. Prescribed-spin convention: BB*v=a*AA*v, s=-a.
! This module does NOT reinterpret torsional or synchronous auxiliary poles.
module rd_modal_metrics
  use rd_kinds, only: wp
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
  implicit none
  private
  integer, parameter, public :: root_finite=0, root_infinite=1, root_indeterminate=2, &
    root_nonfinite=3, root_out_of_range=4, root_underflow=5
  type, public :: modal_metrics_t
    real(wp) :: growth=0._wp, wd=0._wp, radius=0._wp, zeta=0._wp, delta=0._wp
    logical :: valid=.false., zeta_defined=.false., delta_defined=.false., oscillatory=.false.
  end type
  complex(wp), allocatable, save, public :: eigen_alpha(:), eigen_beta(:)
  integer, allocatable, save, public :: eigen_root_status(:)
  real(wp), allocatable, save, public :: eigen_backward_error(:),eigen_abs_error(:),eigen_sensitivity(:)
  logical, allocatable, save, public :: eigen_evidence_ready(:)
  public :: generalized_quotient, record_generalized_roots, prescribed_metrics
  public :: orbit_component, whirl_code, spectrum_report, finite_complex
  public :: record_pencil_evidence,record_schur_evidence,conservative_reference_report
contains
  elemental logical function finite_complex(z)
    complex(wp), intent(in) :: z
    finite_complex=ieee_is_finite(real(z,wp)).and.ieee_is_finite(aimag(z))
  end function

  pure subroutine generalized_quotient(alpha,beta,a,status)
    complex(wp), intent(in) :: alpha,beta
    complex(wp), intent(out) :: a
    integer, intent(out) :: status
    complex(wp) :: z
    real(wp) :: sa,sb,sz,logratio,factor
    a=cmplx(huge(1._wp),0._wp,wp)
    status=root_nonfinite
    if (.not.finite_complex(alpha).or..not.finite_complex(beta)) return
    sa=max(abs(real(alpha,wp)),abs(aimag(alpha)))
    sb=max(abs(real(beta,wp)),abs(aimag(beta)))
    if (sb==0._wp) then
      status=root_infinite
      if (sa==0._wp) status=root_indeterminate
      return
    end if
    if (sa==0._wp) then
      a=cmplx(0._wp,0._wp,wp); status=root_finite; return
    end if
    ! Division of independently normalized complex numbers cannot overflow.
    z=(alpha/sa)/(beta/sb)
    sz=abs(z)
    logratio=log(sa)-log(sb)
    if (logratio+log(sz)>=log(huge(1._wp))) then
      status=root_out_of_range; return
    end if
    ! Conservatively retain an underflow status, rather than call a lost pole zero.
    if (logratio+log(sz)<log(tiny(1._wp))) then
      a=cmplx(0._wp,0._wp,wp); status=root_underflow; return
    end if
    if(max(sa,sb)<sqrt(huge(1._wp))/4._wp.and.min(sa,sb)>4._wp*sqrt(tiny(1._wp))) then
      ! Preserve the ordinary quotient in the safely representable regime.
      a=alpha/beta
    else
      factor=exp(0.5_wp*logratio)
      a=(z*factor)*factor
    end if
    status=root_finite
    if (.not.finite_complex(a)) then
      a=cmplx(huge(1._wp),0._wp,wp); status=root_out_of_range
    end if
  end subroutine

  subroutine record_generalized_roots(alpha,beta,idx,n)
    integer, intent(in) :: n,idx(n)
    complex(wp), intent(in) :: alpha(n),beta(n)
    complex(wp) :: value
    integer :: j
    if (allocated(eigen_alpha)) deallocate(eigen_alpha,eigen_beta,eigen_root_status)
    allocate(eigen_alpha(n),eigen_beta(n),eigen_root_status(n))
    if(allocated(eigen_backward_error)) &
      deallocate(eigen_backward_error,eigen_abs_error,eigen_sensitivity,eigen_evidence_ready)
    allocate(eigen_backward_error(n),eigen_abs_error(n),eigen_sensitivity(n),eigen_evidence_ready(n))
    eigen_backward_error=ieee_value(0._wp,ieee_quiet_nan)
    eigen_abs_error=eigen_backward_error;eigen_sensitivity=eigen_backward_error;eigen_evidence_ready=.false.
    do j=1,n
      eigen_alpha(j)=alpha(idx(j)); eigen_beta(j)=beta(idx(j))
      call generalized_quotient(eigen_alpha(j),eigen_beta(j),value,eigen_root_status(j))
    end do
  end subroutine

  subroutine record_pencil_evidence(aa,bb,left,right,idx,a)
    ! BB*x=a*AA*x. Keep the computed pole; estimate its resolution using
    ! actual residuals and componentwise left/right sensitivity. This is a
    ! first-order diagnostic, not a proof of nonlinear or Lyapunov stability.
    complex(wp),intent(in)::aa(:,:),bb(:,:),left(:,:),right(:,:),a(:)
    integer,intent(in)::idx(:)
    complex(wp),allocatable::ax(:),bx(:),res(:)
    real(wp),allocatable::absa(:,:),absb(:,:),weights(:),xabs(:),yabs(:)
    real(wp)::den,weighted_scale,weighted_residual,gamma,scale
    integer::n,j,k
    n=size(a)
    if(.not.allocated(eigen_evidence_ready))return
    if(size(eigen_evidence_ready)/=n.or.size(idx)/=n)return
    if(any(shape(aa)/=[n,n]).or.any(shape(bb)/=[n,n]))return
    if(any(shape(left)/=[n,n]).or.any(shape(right)/=[n,n]))return
    allocate(ax(n),bx(n),res(n),weights(n),xabs(n),yabs(n))
    absa=abs(aa);absb=abs(bb)
    gamma=8._wp*real(n,wp)*epsilon(1._wp)
    do j=1,n
      k=idx(j)
      if(k<1.or.k>n.or.eigen_root_status(j)/=root_finite)cycle
      if(.not.finite_complex(a(j)))cycle
      xabs=abs(right(:,k));yabs=abs(left(:,k))
      ax=matmul(aa,right(:,k));bx=matmul(bb,right(:,k))
      res=bx-a(j)*ax
      weights=matmul(absb,xabs)+abs(a(j))*matmul(absa,xabs)
      scale=maxval(weights)
      if(.not.ieee_is_finite(scale))cycle
      if(scale==0._wp)then
        if(any(res/=cmplx(0._wp,0._wp,wp)))cycle
        eigen_backward_error(j)=0._wp
      else
        eigen_backward_error(j)=maxval(abs(res))/scale
      endif
      den=abs(dot_product(left(:,k),ax))
      weighted_scale=sum(yabs*weights)
      weighted_residual=sum(yabs*abs(res))
      if(.not.ieee_is_finite(den).or..not.ieee_is_finite(weighted_scale))cycle
      if(.not.ieee_is_finite(weighted_residual))cycle
      if(den<=tiny(1._wp))then
        eigen_sensitivity(j)=huge(1._wp);eigen_abs_error(j)=huge(1._wp)
      else
        eigen_sensitivity(j)=weighted_scale/den
        eigen_abs_error(j)=(weighted_residual+gamma*weighted_scale)/den
      endif
      eigen_evidence_ready(j)=ieee_is_finite(eigen_backward_error(j)).and. &
        ieee_is_finite(eigen_abs_error(j)).and.ieee_is_finite(eigen_sensitivity(j))
    enddo
  end subroutine record_pencil_evidence

  subroutine record_schur_evidence(operator,schur,vectors,poles,omega_ref,ok)
    ! DTGEVC obtains vectors from the existing real Schur form (T,I).
    ! It does not recompute, reorder or replace any family pole.
    real(wp),intent(in)::operator(:,:),schur(:,:),vectors(:,:),omega_ref
    complex(wp),intent(in)::poles(:)
    integer,intent(out)::ok
    real(wp),allocatable::identity(:,:),vl(:,:),vr(:,:),work(:)
    complex(wp),allocatable::left(:,:),right(:,:)
    logical,allocatable::select(:)
    integer,allocatable::idx(:)
    integer::n,j,m
    n=size(poles);ok=-1
    if(any(shape(operator)/=[n,n]).or.any(shape(schur)/=[n,n]))return
    if(any(shape(vectors)/=[n,n]))return
    allocate(identity(n,n),vl(n,n),vr(n,n),work(6*n),select(n),idx(n),left(n,n),right(n,n))
    identity=0._wp
    do j=1,n
      identity(j,j)=1._wp
    enddo
    vl=vectors;vr=vectors;select=.true.;idx=[(j,j=1,n)]
    call dtgevc('B','B',select,n,schur,n,identity,n,vl,n,vr,n,n,m,work,ok)
    if(ok/=0.or.m/=n)return
    j=1
    do while(j<=n)
      if(aimag(poles(j))==0._wp)then
        left(:,j)=cmplx(vl(:,j),0._wp,wp);right(:,j)=cmplx(vr(:,j),0._wp,wp);j=j+1
      else
        if(j>=n)then
          ok=-2;return
        endif
        if(aimag(poles(j))<=0._wp.or.aimag(poles(j+1))>=0._wp)then
          ok=-2;return
        endif
        left(:,j)=cmplx(vl(:,j),vl(:,j+1),wp);right(:,j)=cmplx(vr(:,j),vr(:,j+1),wp)
        left(:,j+1)=conjg(left(:,j));right(:,j+1)=conjg(right(:,j));j=j+2
      endif
    enddo
    call record_pencil_evidence(cmplx(identity,0._wp,wp), &
      cmplx(-omega_ref*operator,0._wp,wp),left,right,idx,-poles)
  end subroutine record_schur_evidence

  subroutine conservative_reference_report(context,rpm,mass,stiffness,damping)
    ! This independent reference is eligible only for the exact conservative
    ! zero-spin subcase. Never symmetrize a nonconservative physical matrix.
    character(len=*),intent(in)::context
    real(wp),intent(in)::rpm,mass(:,:)
    complex(wp),intent(in)::stiffness(:,:),damping(:,:)
    real(wp),allocatable::k(:,:),m(:,:),vectors(:,:),lambda(:),work(:),phi(:),res(:),weights(:)
    real(wp)::query(1),den,bound,backward,scale,gamma,maxres
    integer::n,j,info,lwork,negative,unresolved,positive
    n=size(mass,1)
    if(rpm/=0._wp.or.n<1)return
    if(any(shape(mass)/=[n,n]).or.any(shape(stiffness)/=[n,n]).or.any(shape(damping)/=[n,n]))return
    if(any(damping/=cmplx(0._wp,0._wp,wp)).or.any(aimag(stiffness)/=0._wp))return
    if(.not.all(ieee_is_finite(mass)).or..not.all(finite_complex(stiffness)))return
    if(any(mass/=transpose(mass)).or.any(stiffness/=transpose(stiffness)))return
    k=real(stiffness,wp);m=mass;vectors=k
    allocate(lambda(n),phi(n),res(n),weights(n))
    call dsygv(1,'V','U',n,vectors,n,m,n,lambda,query,-1,info)
    if(info/=0)return
    if(.not.ieee_is_finite(query(1)).or.query(1)>=real(huge(lwork),wp))return
    lwork=max(3*n-1,ceiling(query(1)));allocate(work(lwork));m=mass;vectors=k
    call dsygv(1,'V','U',n,vectors,n,m,n,lambda,work,lwork,info)
    if(info/=0)then
      write(*,'(a,1x,a,1x,i0)') 'RD_AUDIT_V1 CONSERVATIVE_REFERENCE_FAILED',trim(context),info
      return
    endif
    gamma=8._wp*real(n,wp)*epsilon(1._wp);maxres=0._wp
    negative=0;unresolved=0;positive=0
    do j=1,n
      phi=vectors(:,j);res=matmul(k,phi)-lambda(j)*matmul(mass,phi)
      weights=matmul(abs(k),abs(phi))+abs(lambda(j))*matmul(abs(mass),abs(phi))
      scale=maxval(weights);den=abs(dot_product(phi,matmul(mass,phi)))
      backward=0._wp
      if(scale>tiny(1._wp))backward=maxval(abs(res))/scale
      bound=(sum(abs(phi)*abs(res))+gamma*sum(abs(phi)*weights))/den
      maxres=max(maxres,backward)
      if(lambda(j)<-bound)then
        negative=negative+1
      else if(lambda(j)>bound)then
        positive=positive+1
      else
        unresolved=unresolved+1
      endif
      write(*,'(a,1x,a,1x,i0,3(1x,es24.16e3))') &
        'RD_AUDIT_V1 CONSERVATIVE_EIGENVALUE',trim(context),j,lambda(j),bound,backward
    enddo
    write(*,'(a,1x,a,4(1x,i0),1x,es24.16e3)') &
      'RD_AUDIT_V1 CONSERVATIVE_REFERENCE_DSYGV',trim(context),n,negative,unresolved,positive,maxres
  end subroutine conservative_reference_report

  pure function prescribed_metrics(a,absolute_error) result(m)
    complex(wp), intent(in) :: a
    real(wp),intent(in),optional::absolute_error
    type(modal_metrics_t) :: m
    real(wp) :: scale,norm_scaled,r,ratio,pi
    m=modal_metrics_t()
    m%zeta=ieee_value(0._wp,ieee_quiet_nan)
    m%delta=ieee_value(0._wp,ieee_quiet_nan)
    if (.not.finite_complex(a)) return
    ! Historical ADJEIG sentinel is never a physical stable real root.
    if (max(abs(real(a,wp)),abs(aimag(a)))>=huge(1._wp)) return
    r=real(a,wp); m%growth=-r; m%wd=abs(aimag(a))
    scale=max(abs(r),m%wd)
    m%valid=.true.
    if (scale==0._wp) return
    norm_scaled=sqrt((r/scale)**2+(m%wd/scale)**2)
    if (scale>huge(1._wp)/norm_scaled) then
      m%valid=.false.; return
    end if
    m%radius=scale*norm_scaled
    m%zeta=(r/scale)/norm_scaled; m%zeta_defined=.true.
    ! This is a numerical oscillatory threshold, not a damping-ratio cutoff.
    m%oscillatory=m%wd>max(1.e-12_wp,64._wp*epsilon(1._wp)*scale)
    if(present(absolute_error))then
      if(ieee_is_finite(absolute_error).and.absolute_error>=0._wp) &
        m%oscillatory=m%wd>absolute_error
    endif
    if (.not.m%oscillatory) return
    pi=acos(-1._wp)
    if (m%wd<1._wp) then
      if (abs(r)>huge(1._wp)*m%wd/(2._wp*pi)) return
    end if
    ratio=r/m%wd
    if (abs(ratio)>huge(1._wp)/(2._wp*pi)) return
    m%delta=2._wp*pi*ratio
    m%delta_defined=ieee_is_finite(m%delta)
  end function

  elemental real(wp) function orbit_component(phi,phase)
    complex(wp), intent(in) :: phi
    real(wp), intent(in) :: phase
    orbit_component=real(phi,wp)*cos(phase)+aimag(phi)*sin(phase)
  end function

  function whirl_code(x,z,spin,relative_node_tol,linear_tol) result(code)
    complex(wp), intent(in) :: x(:),z(:)
    real(wp), intent(in) :: spin
    real(wp), intent(in), optional :: relative_node_tol,linear_tol
    character(len=2) :: code
    real(wp) :: scale,maximum,chi,ntol,ltol,den
    complex(wp) :: xn,zn
    logical :: fw,bw,active
    integer :: i
    ntol=1.e-10_wp; if(present(relative_node_tol)) ntol=relative_node_tol
    ltol=1.e-6_wp; if(present(linear_tol)) ltol=linear_tol
    code='ND'; fw=.false.; bw=.false.; active=.false.; maximum=0._wp
    if (size(x)/=size(z).or.size(x)==0) return
    if (.not.all(finite_complex(x)).or..not.all(finite_complex(z))) then
      code='UD'; return
    end if
    do i=1,size(x)
      maximum=max(maximum,abs(x(i)),abs(z(i)))
    end do
    if(maximum<=tiny(1._wp)) return
    do i=1,size(x)
      scale=max(abs(x(i)),abs(z(i)))
      if(scale/maximum<=ntol) cycle
      active=.true.; xn=x(i)/scale; zn=z(i)/scale
      den=abs(xn)**2+abs(zn)**2
      chi=2._wp*aimag(xn*conjg(zn))/den
      if (abs(spin)<=1.e-12_wp) cycle
      if (spin<0._wp) chi=-chi
      if(chi>ltol) fw=.true.
      if(chi<-ltol) bw=.true.
    end do
    if (.not.active) return
    if(abs(spin)<=1.e-12_wp) then
      code='UD'
    else if(fw.and.bw) then
      code='MX'
    else if(fw) then
      code='FW'
    else if(bw) then
      code='BW'
    else
      code='LN'
    end if
  end function

  subroutine spectrum_report(context,rpm,a)
    character(len=*), intent(in) :: context
    real(wp), intent(in) :: rpm
    complex(wp), intent(in) :: a(:)
    type(modal_metrics_t) :: m
    integer :: j,nfinite,ninvalid,nunstable,nmarginal,nreal,nquality,nunknown,nbad,nrawpositive
    real(wp) :: maxgrowth,tol,maxres
    character(len=32) :: status
    logical :: have_metadata,have_quality,qualified
    nfinite=0; ninvalid=0; nunstable=0; nmarginal=0; nreal=0
    maxgrowth=-huge(1._wp)
    nquality=0;nunknown=0;nbad=0;nrawpositive=0;maxres=0._wp
    have_metadata=.false.
    if(allocated(eigen_root_status)) have_metadata=size(eigen_root_status)==size(a)
    have_quality=.false.
    if(allocated(eigen_evidence_ready))have_quality=size(eigen_evidence_ready)==size(a)
    do j=1,size(a)
      if(have_metadata) then
        if(eigen_root_status(j)/=root_finite) then
          ninvalid=ninvalid+1
          write(*,'(a,1x,a,1x,es24.16e3,2(1x,i0),4(1x,es24.16e3))') &
            'RD_AUDIT_V1 ROOT_STATUS',trim(context),rpm,j,eigen_root_status(j), &
            real(eigen_alpha(j),wp),aimag(eigen_alpha(j)),real(eigen_beta(j),wp),aimag(eigen_beta(j))
          cycle
        end if
      end if
      qualified=.false.
      if(have_quality)qualified=eigen_evidence_ready(j)
      m=prescribed_metrics(a(j))
      if(qualified)m=prescribed_metrics(a(j),eigen_abs_error(j))
      if(.not.m%valid) then
        ninvalid=ninvalid+1; cycle
      end if
      nfinite=nfinite+1; maxgrowth=max(maxgrowth,m%growth)
      if(.not.m%oscillatory) nreal=nreal+1
      if(m%growth>0._wp)nrawpositive=nrawpositive+1
      tol=huge(1._wp)
      if(qualified)then
        nquality=nquality+1;maxres=max(maxres,eigen_backward_error(j))
        if(eigen_backward_error(j)<=1.e-10_wp)then
          tol=eigen_abs_error(j)
        else
          nbad=nbad+1
        endif
      else
        nunknown=nunknown+1
      endif
      if(m%growth>tol) nunstable=nunstable+1
      if(abs(m%growth)<=tol) nmarginal=nmarginal+1
      if(m%growth>0._wp.or..not.m%oscillatory) then
        write(*,'(a,1x,a,1x,es24.16e3,1x,i0,3(1x,es24.16e3))') &
          'RD_AUDIT_V1 STABILITY_ROOT',trim(context),rpm,j,m%growth,-aimag(a(j)),m%wd
        if(qualified)then
          write(*,'(a,1x,a,1x,es24.16e3,1x,i0,3(1x,es24.16e3),1x,l1)') &
            'RD_AUDIT_V1 ROOT_QUALITY',trim(context),rpm,j,eigen_backward_error(j), &
            eigen_sensitivity(j),eigen_abs_error(j),abs(m%growth)>tol
        endif
      end if
    end do
    if(nunstable>0) then
      status='UNSTABLE'
      if(ninvalid>0.or.nunknown>0.or.nbad>0) status='UNSTABLE_INCOMPLETE_SPECTRUM'
    else if(ninvalid>0.or.nfinite==0.or.nunknown>0.or.nbad>0) then
      status='INDETERMINATE'
    else if(nmarginal>0) then
      ! No unsupported Lyapunov-stability claim for imaginary-axis/defective roots.
      status='MARGINAL_UNRESOLVED'
    else
      status='ASYMPTOTICALLY_STABLE'
    end if
    if(nfinite==0) maxgrowth=ieee_value(0._wp,ieee_quiet_nan)
    write(*,'(a,1x,a,1x,es24.16e3,1x,a,1x,es24.16e3,5(1x,i0))') &
      'RD_AUDIT_V1 SPECTRUM',trim(context),rpm,trim(status),maxgrowth, &
      size(a),nfinite,ninvalid,nunstable,nreal
    write(*,'(a,1x,a,1x,es24.16e3,4(1x,i0),1x,es24.16e3)') &
      'RD_AUDIT_V1 SPECTRUM_QUALITY',trim(context),rpm,nquality,nunknown,nbad,nrawpositive,maxres
  end subroutine
end module rd_modal_metrics
