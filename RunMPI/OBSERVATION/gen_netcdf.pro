; Return the boundary condition given by the Allen CLV
function i0_allen, wl, mu
	ic = ddread('ic.dat',/noverb)
	cl = ddread('cl.dat',/noverb)
   PC = 2.99792458d10
   PH = 6.62606876d-27

; Wavelength in A
   ic(0,*) = 1.d4 * ic(0,*)
; I_lambda to I_nu
   ic(1,*) = 1.d14 * ic(1,*) * (ic(0,*)*1.d-8)^2 / PC

   cl(0,*) = 1.d4 * cl(0,*)

   u = interpol(cl(1,*),cl(0,*),wl)
   v = interpol(cl(2,*),cl(0,*),wl)
   i0 = interpol(ic(1,*),ic(0,*),wl)

   imu = 1.d0 - u - v + u * mu + v * mu^2
   
   return, i0*imu
end



; This routine generates a NetCDF file with the
; observations ready for Hazel-MPI
; stI, stQ, stU, stV are arrays of size [npixel, nlambda]
; sigmaI, sigmaQ, sigmaU, sigmaV are arrays of size [npixel, nlambda]
; lambda is an array of size [nlambda]
; boundary is an array of size [npixel, 4] with the boundary conditions [I0,Q0,U0,V0] for every pixel
; height is an array of size [npixel] indicating the height of the pixel over the surface in arcsec
; obs_theta is an array of size [npixel] indicating the angle of the observation in degrees
; obs_gamma is an array of size [npixel] indicating the angle of the reference for Stokes Q
; mask is an array of the original dimensions of the observations that is used later to
;   reconstruct the inverted maps [nx,ny]
pro gen_netcdf, lambda, stI, stQ, stU, stV, sigmaI, sigmaQ, sigmaU, sigmaV, boundary, height, $
	obs_theta, obs_gamma, mask, outputfile

	npixel = n_elements(stI[*,0])
	nlambda = n_elements(lambda)
	ncol = 8

	map = dblarr(npixel,8,nlambda)

	map[*,0,*] = stI
	map[*,1,*] = stQ
	map[*,2,*] = stU
	map[*,3,*] = stV
	map[*,4,*] = sigmaI
	map[*,5,*] = sigmaQ
	map[*,6,*] = sigmaU
	map[*,7,*] = sigmaV
	
	dim_map = size(mask, /dimensions)
			
	file_id = ncdf_create(outputfile, /clobber)
	nx_dim = ncdf_dimdef(file_id, 'npixel', npixel)
	ncol_dim = ncdf_dimdef(file_id, 'ncolumns', ncol)
	nstokespar_dim = ncdf_dimdef(file_id, 'nstokes_par', 4)
	nlambda_dim = ncdf_dimdef(file_id, 'nlambda', nlambda)
	nxmap_dim = ncdf_dimdef(file_id, 'nx', reform(dim_map[0]))
	nymap_dim = ncdf_dimdef(file_id, 'ny', reform(dim_map[1]))
	lambda_id = ncdf_vardef(file_id, 'lambda', [nlambda_dim], /double)
	stI_id = ncdf_vardef(file_id, 'map', [nx_dim,ncol_dim,nlambda_dim], /double)
	boundary_id = ncdf_vardef(file_id, 'boundary', [nx_dim, nstokespar_dim], /double)
	height_id = ncdf_vardef(file_id, 'height', [nx_dim], /double)
	obstheta_id = ncdf_vardef(file_id, 'obs_theta', [nx_dim], /double)
	obsgamma_id = ncdf_vardef(file_id, 'obs_gamma', [nx_dim], /double)
	mask_id = ncdf_vardef(file_id, 'mask', [nxmap_dim, nymap_dim], /short)
	ncdf_control, file_id, /endef
	
	ncdf_varput, file_id, lambda_id, lambda
	ncdf_varput, file_id, stI_id, map
	ncdf_varput, file_id, boundary_id, boundary
	ncdf_varput, file_id, height_id, height
	ncdf_varput, file_id, obstheta_id, obs_theta
	ncdf_varput, file_id, obsgamma_id, obs_gamma
	ncdf_varput, file_id, mask_id, mask
	ncdf_close, file_id		
end


pro test
	dat = ddread('prominence_ApJ_642_554.prof',offset=1,/count,/double)
	dat = congrid(dat,9,100)
	
	nlambda = n_elements(dat[0,*])
	npixel = 4
	map = dblarr(npixel,8,nlambda)
	lambda = reform(dat[0,*])
	for i = 0, npixel-1 do begin
		map[i,*,*] = dat[1:*,*]
	endfor
	
	mu = [1.d0, 0.3d0, 1.d0, 0.3d0]
	obs_theta = acos(mu) * 180.d0 / !DPI
 	boundary = fltarr(npixel,4)
 	boundary[*,0] = i0_allen(10830.d0, mu)
 	height = [3.d0, 5.d0, 3.d0, 5.d0]
 	obs_gamma = replicate(90.d0,npixel)
	mask = replicate(1.0,2,2)
 	
	gen_netcdf, lambda, reform(map[*,0,*]), reform(map[*,1,*]), reform(map[*,2,*]), reform(map[*,3,*]), $
		reform(map[*,4,*]), reform(map[*,5,*]), reform(map[*,6,*]), reform(map[*,7,*]), boundary,$
		height, obs_theta, obs_gamma, mask, 'test.nc'
	stop
end