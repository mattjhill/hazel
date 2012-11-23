module synth
use vars
use SEE
use rt_coef
implicit none
contains
	
!------------------------------------------------------------
! Do a synthesis calling the appropriate routines
!------------------------------------------------------------
	subroutine do_synthesis(in_params,in_fixed,in_observation,output)
	type(variable_parameters) :: in_params, in_trial
	type(type_observation) :: in_observation
	type(fixed_parameters) :: in_fixed
	integer :: i
	real(kind=8) :: output(0:3,in_fixed%no), I0, Q0, U0, V0, ds, Imax, mu, Ic, factor, eta0, psim, psi0
	real(kind=8), allocatable, dimension(:) :: epsI, epsQ, epsU, epsV, etaI, etaQ, etaU, etaV, dtau			
	real(kind=8), allocatable, dimension(:) :: rhoQ, rhoU, rhoV, delta
	real(kind=8), allocatable :: StokesM(:), kappa_prime(:,:), kappa_star(:,:), identity(:,:), source(:), m1(:,:), m2(:,:), Stokes0(:)
	real(kind=8), allocatable :: O_evol(:,:), psi_matrix(:,:)
		
! Fill the statistical equilibrium equations
		call fill_SEE(input_model_file, in_params, in_fixed)
				
! Calculate the absorption/emission coefficients for a given transition
		call calc_rt_coef(in_params, in_fixed, in_observation)
						
!****************		
! Only emission
!****************
		if (synthesis_mode == 0) then
			if (in_fixed%use_atomic_pol == 1) then
				Imax = maxval(epsilon(0,:))
				do i = 0, 3
					output(i,:) = epsilon(i,:) / Imax
				enddo
			else
				Imax = maxval(epsilon(0,:))
				do i = 0, 3
					output(i,:) = epsilon_zeeman(i,:) / Imax
				enddo
			endif
		endif
		
!****************		
! Slab case
!****************
		if (synthesis_mode == 1) then
						
			if (.not.allocated(epsI)) allocate(epsI(in_fixed%no))
			if (.not.allocated(epsQ)) allocate(epsQ(in_fixed%no))
			if (.not.allocated(epsU)) allocate(epsU(in_fixed%no))
			if (.not.allocated(epsV)) allocate(epsV(in_fixed%no))
			if (.not.allocated(etaI)) allocate(etaI(in_fixed%no))
			if (.not.allocated(etaQ)) allocate(etaQ(in_fixed%no))
			if (.not.allocated(etaU)) allocate(etaU(in_fixed%no))
			if (.not.allocated(etaV)) allocate(etaV(in_fixed%no))
			if (.not.allocated(dtau)) allocate(dtau(in_fixed%no))
			
			I0 = in_fixed%Stokes_incident(0)
			Q0 = in_fixed%Stokes_incident(1)
			U0 = in_fixed%Stokes_incident(2)
			V0 = in_fixed%Stokes_incident(3)
						
			if (in_fixed%use_atomic_pol == 1) then
				epsI = epsilon(0,:)
				epsQ = epsilon(1,:)
				epsU = epsilon(2,:)
				epsV = epsilon(3,:)
				etaI = eta(0,:) - use_stim_emission_RT * eta_stim(0,:)
				etaQ = eta(1,:) - use_stim_emission_RT * eta_stim(1,:)
				etaU = eta(2,:) - use_stim_emission_RT * eta_stim(2,:)
				etaV = eta(3,:) - use_stim_emission_RT * eta_stim(3,:)
			else
				epsI = epsilon_zeeman(0,:)
				epsQ = epsilon_zeeman(1,:)
				epsU = epsilon_zeeman(2,:)
				epsV = epsilon_zeeman(3,:)
				etaI = eta_zeeman(0,:) - use_stim_emission_RT * eta_stim_zeeman(0,:) + 1.d-20
				etaQ = eta_zeeman(1,:) - use_stim_emission_RT * eta_stim_zeeman(1,:) + 1.d-20
				etaU = eta_zeeman(2,:) - use_stim_emission_RT * eta_stim_zeeman(2,:) + 1.d-20
				etaV = eta_zeeman(3,:) - use_stim_emission_RT * eta_stim_zeeman(3,:) + 1.d-20
			endif
						
			ds = in_params%dtau / maxval(etaI)
			dtau = etaI * ds

			output(0,:) = I0 * exp(-dtau) + epsI/etaI * (1.d0-exp(-dtau))

		  	output(1,:) = Q0 * exp(-dtau) + epsQ/etaI * (1.d0-exp(-dtau)) - epsI * etaQ/etaI**2 * (1.d0-exp(-dtau)) + &
		   	etaQ/etaI * dtau * exp(-dtau) * (epsI/etaI-I0)

	 	  	output(2,:) = U0 * exp(-dtau) + epsU/etaI * (1.d0-exp(-dtau)) - epsI * etaU/etaI**2 * (1.d0-exp(-dtau)) + &
		   	etaU/etaI * dtau * exp(-dtau) * (epsI/etaI-I0)

	 	  	output(3,:) = V0 * exp(-dtau) + epsV/etaI * (1.d0-exp(-dtau)) - epsI * etaV/etaI**2 * (1.d0-exp(-dtau)) + &
		   	etaV/etaI * dtau * exp(-dtau) * (epsI/etaI-I0)							
			

			Imax = maxval(output(0,:))
			do i = 0, 3
				output(i,:) = output(i,:) / Imax
			enddo
			
		endif
		

!****************		
! Milne-Eddington without magneto-optical effects
!****************
		if (synthesis_mode == 2) then
						
			if (.not.allocated(epsI)) allocate(epsI(in_fixed%no))
			if (.not.allocated(epsQ)) allocate(epsQ(in_fixed%no))
			if (.not.allocated(epsU)) allocate(epsU(in_fixed%no))
			if (.not.allocated(epsV)) allocate(epsV(in_fixed%no))
			if (.not.allocated(etaI)) allocate(etaI(in_fixed%no))
			if (.not.allocated(etaQ)) allocate(etaQ(in_fixed%no))
			if (.not.allocated(etaU)) allocate(etaU(in_fixed%no))
			if (.not.allocated(etaV)) allocate(etaV(in_fixed%no))
			if (.not.allocated(rhoQ)) allocate(rhoQ(in_fixed%no))
			if (.not.allocated(rhoU)) allocate(rhoU(in_fixed%no))
			if (.not.allocated(rhoV)) allocate(rhoV(in_fixed%no))
			if (.not.allocated(dtau)) allocate(dtau(in_fixed%no))
						
						
			if (in_fixed%use_atomic_pol == 1) then
				epsI = epsilon(0,:)
				epsQ = epsilon(1,:)
				epsU = epsilon(2,:)
				epsV = epsilon(3,:)
				
! Include stimulated emission depending on the flag
				etaI = eta(0,:) - use_stim_emission_RT * eta_stim(0,:)
				etaQ = eta(1,:) - use_stim_emission_RT * eta_stim(1,:)
				etaU = eta(2,:) - use_stim_emission_RT * eta_stim(2,:)
				etaV = eta(3,:) - use_stim_emission_RT * eta_stim(3,:)
				
! Magneto-optical terms				
				if (use_mag_opt_RT == 1) then
					rhoQ = mag_opt(1,:) - use_stim_emission_RT * mag_opt_stim(1,:)
					rhoU = mag_opt(2,:) - use_stim_emission_RT * mag_opt_stim(2,:)
					rhoV = mag_opt(3,:) - use_stim_emission_RT * mag_opt_stim(3,:)
				else
					rhoQ = 0.d0
					rhoU = 0.d0
					rhoV = 0.d0
				endif
			else
				epsI = epsilon(0,:)
				epsQ = epsilon(1,:)
				epsU = epsilon(2,:)
				epsV = epsilon(3,:)
				
! Include stimulated emission depending on the flag				
				etaI = eta_zeeman(0,:) - use_stim_emission_RT * eta_stim_zeeman(0,:)
				etaQ = eta_zeeman(1,:) - use_stim_emission_RT * eta_stim_zeeman(1,:)
				etaU = eta_zeeman(2,:) - use_stim_emission_RT * eta_stim_zeeman(2,:)
				etaV = eta_zeeman(3,:) - use_stim_emission_RT * eta_stim_zeeman(3,:)
				
! Magneto-optical terms
				if (use_mag_opt_RT == 1) then
					rhoQ = mag_opt_zeeman(1,:) - use_stim_emission_RT * mag_opt_stim_zeeman(1,:)
					rhoU = mag_opt_zeeman(2,:) - use_stim_emission_RT * mag_opt_stim_zeeman(2,:)
					rhoV = mag_opt_zeeman(3,:) - use_stim_emission_RT * mag_opt_stim_zeeman(3,:)
				else
					rhoQ = 0.d0
					rhoU = 0.d0
					rhoV = 0.d0
				endif
			endif
			
			mu = cos(in_fixed%thetad*PI/180.d0)
			Ic = (1.d0 + in_params%beta*mu)						

! The eta_0 parameter in the ME model is given by eq. 9.31 in the book: eta_0 = k_L / (k_c * Delta_nu)
! where k_L=h*nu/(4*Pi)*Blu*N
! Since the eta parameters already include part of k_L, I have to divide my etaI by this quantity to
! transform them in the kI, kQ, kU and kV quantities in eq. 9.39 in the book
			factor = PH * in_fixed%nu / (4.d0*PI) * in_fixed%Blu
			eta0 = in_params%dtau
			
! MILNE-EDDINGTON INCLUDING MAGNETO-OPTICAL EFFECTS
			etaI = etaI / factor
			etaQ = etaQ / factor
			etaU = etaU / factor
			etaV = etaV / factor
			rhoQ = rhoQ / factor
			rhoU = rhoU / factor
			rhoV = rhoV / factor

			etaI = etaI * eta0
			etaQ = etaQ * eta0
			etaU = etaU * eta0
			etaV = etaV * eta0
			rhoQ = rhoQ * eta0
			rhoU = rhoU * eta0
			rhoV = rhoV * eta0

			if (.not.allocated(delta)) allocate(delta(in_fixed%no))
			delta = (1.d0+etaI)**4 + (1.d0+etaI)**2 * (rhoQ**2+rhoU**2+rhoV**2-etaQ**2-etaU**2-etaV**2) - &
				(etaQ*rhoQ+etaU*rhoU+etaV*rhoV)**2

			output(0,:) = 1.d0+in_params%beta * mu / delta * (1.d0+etaI) * ((1.d0+etaI)**2 + rhoQ**2 + rhoU**2 + rhoV**2)

			output(1,:) = -in_params%beta * mu / delta * ((1.d0+etaI)**2 * etaQ - (1.d0+etaI)*(etaU*rhoV-etaV*rhoU) + &
				rhoQ*(etaQ*rhoQ + etaU*rhoU + etaV*rhoV))

			output(2,:) = -in_params%beta * mu / delta * ((1.d0+etaI)**2 * etaU - (1.d0+etaI)*(etaV*rhoQ-etaQ*rhoV) + &
				rhoU*(etaQ*rhoQ + etaU*rhoU + etaV*rhoV))

			output(3,:) = -in_params%beta * mu / delta * ((1.d0+etaI)**2 * etaV - (1.d0+etaI)*(etaQ*rhoU-etaU*rhoQ) + &
				rhoV*(etaQ*rhoQ + etaU*rhoU + etaV*rhoV))								
			
! Normalization to the continuum intensity
			do i = 0, 3
				output(i,:) = output(i,:) / Ic
			enddo
			
		endif
		
!****************		
! Slab case with DELOPAR
!****************
		if (synthesis_mode == 3) then
			if (.not.allocated(epsI)) allocate(epsI(in_fixed%no))
			if (.not.allocated(epsQ)) allocate(epsQ(in_fixed%no))
			if (.not.allocated(epsU)) allocate(epsU(in_fixed%no))
			if (.not.allocated(epsV)) allocate(epsV(in_fixed%no))
			if (.not.allocated(etaI)) allocate(etaI(in_fixed%no))
			if (.not.allocated(etaQ)) allocate(etaQ(in_fixed%no))
			if (.not.allocated(etaU)) allocate(etaU(in_fixed%no))
			if (.not.allocated(etaV)) allocate(etaV(in_fixed%no))
			if (.not.allocated(rhoQ)) allocate(rhoQ(in_fixed%no))
			if (.not.allocated(rhoU)) allocate(rhoU(in_fixed%no))
			if (.not.allocated(rhoV)) allocate(rhoV(in_fixed%no))
			if (.not.allocated(dtau)) allocate(dtau(in_fixed%no))
			
			if (.not.allocated(StokesM)) allocate(StokesM(4))
			if (.not.allocated(identity)) then
				allocate(identity(4,4))
				identity = 0.d0
				do i = 1, 4
					identity(i,i) = 1.d0
				enddo
			endif
			if (.not.allocated(source)) allocate(source(4))
			if (.not.allocated(kappa_prime)) allocate(kappa_prime(4,4))
			if (.not.allocated(m1)) allocate(m1(4,4))
			if (.not.allocated(m2)) allocate(m2(4,4))
			if (.not.allocated(Stokes0)) allocate(Stokes0(4))
			
			
			StokesM(1) = in_fixed%Stokes_incident(0)
			StokesM(2) = in_fixed%Stokes_incident(1)
			StokesM(3) = in_fixed%Stokes_incident(2)
			StokesM(4) = in_fixed%Stokes_incident(3)
						
			if (in_fixed%use_atomic_pol == 1) then
! Emission				
				epsI = epsilon(0,:)
				epsQ = epsilon(1,:)
				epsU = epsilon(2,:)
				epsV = epsilon(3,:)
				
! Absorption including stimulated emission
				etaI = eta(0,:) - use_stim_emission_RT * eta_stim(0,:)
				etaQ = eta(1,:) - use_stim_emission_RT * eta_stim(1,:)
				etaU = eta(2,:) - use_stim_emission_RT * eta_stim(2,:)
				etaV = eta(3,:) - use_stim_emission_RT * eta_stim(3,:)

! Magneto-optical effects
				if (use_mag_opt_RT == 1) then
					rhoQ = mag_opt(1,:) - use_stim_emission_RT * mag_opt_stim(1,:)
					rhoU = mag_opt(2,:) - use_stim_emission_RT * mag_opt_stim(2,:)
					rhoV = mag_opt(3,:) - use_stim_emission_RT * mag_opt_stim(3,:)
				else
					rhoQ = 0.d0
					rhoU = 0.d0
					rhoV = 0.d0
				endif
			else
! Emission
				epsI = epsilon_zeeman(0,:)
				epsQ = epsilon_zeeman(1,:)
				epsU = epsilon_zeeman(2,:)
				epsV = epsilon_zeeman(3,:)

! Absorption including stimulated emission
				etaI = eta_zeeman(0,:) - use_stim_emission_RT * eta_stim_zeeman(0,:) + 1.d-20
				etaQ = eta_zeeman(1,:) - use_stim_emission_RT * eta_stim_zeeman(1,:) + 1.d-20
				etaU = eta_zeeman(2,:) - use_stim_emission_RT * eta_stim_zeeman(2,:) + 1.d-20
				etaV = eta_zeeman(3,:) - use_stim_emission_RT * eta_stim_zeeman(3,:) + 1.d-20

! Magneto-optical terms
				if (use_mag_opt_RT == 1) then
					rhoQ = mag_opt_zeeman(1,:) - use_stim_emission_RT * mag_opt_stim_zeeman(1,:)
					rhoU = mag_opt_zeeman(2,:) - use_stim_emission_RT * mag_opt_stim_zeeman(2,:)
					rhoV = mag_opt_zeeman(3,:) - use_stim_emission_RT * mag_opt_stim_zeeman(3,:)
				else
					rhoQ = 0.d0
					rhoU = 0.d0
					rhoV = 0.d0
				endif
			endif
			
			ds = in_params%dtau / maxval(etaI)
			dtau = etaI * ds
			
			do i = 1, in_fixed%no
				call fill_absorption_matrix(kappa_prime,etaI(i),etaQ(i),etaU(i),etaV(i),rhoQ(i),rhoU(i),rhoV(i))
				kappa_prime = kappa_prime / etaI(i) - identity
				source(1) = epsI(i) / etaI(i)
				source(2) = epsQ(i) / etaI(i)
				source(3) = epsU(i) / etaI(i)
				source(4) = epsV(i) / etaI(i)
				
				psi0 = (dtau(i) - 1.d0 + exp(-dtau(i))) / dtau(i)
				psim = 1.d0 - exp(-dtau(i)) - psi0
				
				m1 = exp(-dtau(i))*identity - psim * kappa_prime
				m2 = identity + psi0 * kappa_prime
				
				call invert(m2)
				
				Stokes0 = matmul(m2,matmul(m1,StokesM)+(psim+psi0)*source)
				
				output(0,i) = Stokes0(1)
				output(1,i) = Stokes0(2)
				output(2,i) = Stokes0(3)
				output(3,i) = Stokes0(4)
				
			enddo
										
			Imax = maxval(output(0,:))
			do i = 0, 3
				output(i,:) = output(i,:) / Imax
			enddo
			
		endif		
		
!****************		
! Slab case with approximate solution
!****************
		if (synthesis_mode == 4) then
						
			if (.not.allocated(epsI)) allocate(epsI(in_fixed%no))
			if (.not.allocated(epsQ)) allocate(epsQ(in_fixed%no))
			if (.not.allocated(epsU)) allocate(epsU(in_fixed%no))
			if (.not.allocated(epsV)) allocate(epsV(in_fixed%no))
			if (.not.allocated(etaI)) allocate(etaI(in_fixed%no))
			if (.not.allocated(etaQ)) allocate(etaQ(in_fixed%no))
			if (.not.allocated(etaU)) allocate(etaU(in_fixed%no))
			if (.not.allocated(etaV)) allocate(etaV(in_fixed%no))
			if (.not.allocated(dtau)) allocate(dtau(in_fixed%no))
			
			I0 = in_fixed%Stokes_incident(0)
			Q0 = in_fixed%Stokes_incident(1)
			U0 = in_fixed%Stokes_incident(2)
			V0 = in_fixed%Stokes_incident(3)
						
			if (in_fixed%use_atomic_pol == 1) then
				epsI = epsilon(0,:)
				epsQ = epsilon(1,:)
				epsU = epsilon(2,:)
				epsV = epsilon(3,:)
				etaI = eta(0,:)
				etaQ = eta(1,:)
				etaU = eta(2,:)
				etaV = eta(3,:)
			else
				epsI = epsilon_zeeman(0,:)
				epsQ = epsilon_zeeman(1,:)
				epsU = epsilon_zeeman(2,:)
				epsV = epsilon_zeeman(3,:)
				etaI = eta_zeeman(0,:) + 1.d-20
				etaQ = eta_zeeman(1,:) + 1.d-20
				etaU = eta_zeeman(2,:) + 1.d-20
				etaV = eta_zeeman(3,:) + 1.d-20
			endif
						
			ds = in_params%dtau / maxval(etaI)
			dtau = etaI * ds

			output(0,:) = I0 + (epsI - etaI * I0) * in_params%dtau !dtau / etaI

		  	output(1,:) = Q0 + (epsQ - etaQ * I0) * in_params%dtau !dtau / etaI

	 	  	output(2,:) = U0 + (epsU - etaU * I0) * in_params%dtau !dtau / etaI

	 	  	output(3,:) = V0 + (epsV - etaV * I0) * in_params%dtau !dtau / etaI
			

			Imax = maxval(output(0,:))
			do i = 0, 3
				output(i,:) = output(i,:) / Imax
			enddo
			
		endif
				
!****************		
! Slab case with EXACT SOLUTION
!****************
		if (synthesis_mode == 5) then
			if (.not.allocated(epsI)) allocate(epsI(in_fixed%no))
			if (.not.allocated(epsQ)) allocate(epsQ(in_fixed%no))
			if (.not.allocated(epsU)) allocate(epsU(in_fixed%no))
			if (.not.allocated(epsV)) allocate(epsV(in_fixed%no))
			if (.not.allocated(etaI)) allocate(etaI(in_fixed%no))
			if (.not.allocated(etaQ)) allocate(etaQ(in_fixed%no))
			if (.not.allocated(etaU)) allocate(etaU(in_fixed%no))
			if (.not.allocated(etaV)) allocate(etaV(in_fixed%no))
			if (.not.allocated(rhoQ)) allocate(rhoQ(in_fixed%no))
			if (.not.allocated(rhoU)) allocate(rhoU(in_fixed%no))
			if (.not.allocated(rhoV)) allocate(rhoV(in_fixed%no))
			if (.not.allocated(dtau)) allocate(dtau(in_fixed%no))
			
			if (.not.allocated(StokesM)) allocate(StokesM(4))
			if (.not.allocated(identity)) then
				allocate(identity(4,4))
				identity = 0.d0
				do i = 1, 4
					identity(i,i) = 1.d0
				enddo
			endif
			if (.not.allocated(source)) allocate(source(4))
			if (.not.allocated(kappa_star)) allocate(kappa_star(4,4))
			if (.not.allocated(O_evol)) allocate(O_evol(4,4))
			if (.not.allocated(psi_matrix)) allocate(psi_matrix(4,4))
			if (.not.allocated(m1)) allocate(m1(4,4))
			if (.not.allocated(m2)) allocate(m2(4,4))
			if (.not.allocated(Stokes0)) allocate(Stokes0(4))
			
			StokesM(1) = in_fixed%Stokes_incident(0)
			StokesM(2) = in_fixed%Stokes_incident(1)
			StokesM(3) = in_fixed%Stokes_incident(2)
			StokesM(4) = in_fixed%Stokes_incident(3)
						
			if (in_fixed%use_atomic_pol == 1) then
! Emission				
				epsI = epsilon(0,:)
				epsQ = epsilon(1,:)
				epsU = epsilon(2,:)
				epsV = epsilon(3,:)
				
! Absorption including stimulated emission
				etaI = eta(0,:) - use_stim_emission_RT * eta_stim(0,:)
				etaQ = eta(1,:) - use_stim_emission_RT * eta_stim(1,:)
				etaU = eta(2,:) - use_stim_emission_RT * eta_stim(2,:)
				etaV = eta(3,:) - use_stim_emission_RT * eta_stim(3,:)

! Magneto-optical effects
				if (use_mag_opt_RT == 1) then
					rhoQ = mag_opt(1,:) - use_stim_emission_RT * mag_opt_stim(1,:)
					rhoU = mag_opt(2,:) - use_stim_emission_RT * mag_opt_stim(2,:)
					rhoV = mag_opt(3,:) - use_stim_emission_RT * mag_opt_stim(3,:)
				else
					rhoQ = 0.d0
					rhoU = 0.d0
					rhoV = 0.d0
				endif
			else
! Emission
				epsI = epsilon_zeeman(0,:)
				epsQ = epsilon_zeeman(1,:)
				epsU = epsilon_zeeman(2,:)
				epsV = epsilon_zeeman(3,:)

! Absorption including stimulated emission
				etaI = eta_zeeman(0,:) - use_stim_emission_RT * eta_stim_zeeman(0,:) + 1.d-20
				etaQ = eta_zeeman(1,:) - use_stim_emission_RT * eta_stim_zeeman(1,:) + 1.d-20
				etaU = eta_zeeman(2,:) - use_stim_emission_RT * eta_stim_zeeman(2,:) + 1.d-20
				etaV = eta_zeeman(3,:) - use_stim_emission_RT * eta_stim_zeeman(3,:) + 1.d-20

! Magneto-optical terms
				if (use_mag_opt_RT == 1) then
					rhoQ = mag_opt_zeeman(1,:) - use_stim_emission_RT * mag_opt_stim_zeeman(1,:)
					rhoU = mag_opt_zeeman(2,:) - use_stim_emission_RT * mag_opt_stim_zeeman(2,:)
					rhoV = mag_opt_zeeman(3,:) - use_stim_emission_RT * mag_opt_stim_zeeman(3,:)
				else
					rhoQ = 0.d0
					rhoU = 0.d0
					rhoV = 0.d0
				endif
			endif
			
			ds = in_params%dtau / maxval(etaI)
			dtau = etaI * ds
			
			do i = 1, in_fixed%no
				call fill_absorption_matrix(kappa_star,etaI(i),etaQ(i),etaU(i),etaV(i),rhoQ(i),rhoU(i),rhoV(i))
				kappa_star = kappa_star / etaI(i)
				source(1) = epsI(i) / etaI(i)
				source(2) = epsQ(i) / etaI(i)
				source(3) = epsU(i) / etaI(i)
				source(4) = epsV(i) / etaI(i)

! Evaluate the evolution operator
				call evol_operator(kappa_star,dtau(i),O_evol)

! Calculate K*^(-1)
				m1 = kappa_star
				call invert(m1)

				m2 = identity - O_evol
				Psi_matrix = matmul(m1,m2)

! Simplified version taking into account that the source function is constant, so that
!  I0 = exp(-K^* * tau_MO) * I_sun + (PsiM+Psi0)*S  with
! PsiM = U0-U1/tau_MO    and PsiO = U1/m
! U0 = (K*)^(-1) (1-exp(-K^* tau_MO)    and      U1 = (K*)^(-1) (m*1 - U0)
				Stokes0 = matmul(O_evol,StokesM) + matmul(Psi_matrix,source)
				
				output(0,i) = Stokes0(1)
				output(1,i) = Stokes0(2)
				output(2,i) = Stokes0(3)
				output(3,i) = Stokes0(4)
				
			enddo
										
			Imax = maxval(output(0,:))
			do i = 0, 3
				output(i,:) = output(i,:) / Imax
			enddo
			
		endif
		
		in_fixed%total_forward_modeling = in_fixed%total_forward_modeling + 1
	
	end subroutine do_synthesis
end module synth