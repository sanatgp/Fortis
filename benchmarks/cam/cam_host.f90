! Standalone transcription of E3SM mmf_nn_emulator.F90 (climsim-online fork) around the NN call.
! Same statements, same order, same array shapes and precisions; state%... replaced by flat arrays
! read from cam_state.bin. Variable list is ClimSim v1 (124 in, 128 out) to match the published
! baseline MLP. Normalization is E3SM's min-max form; post-processing is E3SM's verbatim.
program cam_host
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: r8 = kind(1.0d0), real32 = kind(1.0)
  integer, parameter :: pcols = 384, pver = 60, inputlength = 124, outputlength = 128, nsteps = 100
  real(r8), parameter :: cpair = 1004.64_r8, ztodt = 1200._r8
  real(r8) :: t(pcols,pver), q(pcols,pver), ps(pcols), solin(pcols), lhflx(pcols), shflx(pcols), coszrs(pcols)
  real(r8) :: in_mean(inputlength), in_max(inputlength), in_min(inputlength), out_scale(outputlength)
  real(r8) :: input(pcols,inputlength), output(pcols,outputlength)
  real(real32) :: input_torch(inputlength,pcols), output_torch(outputlength,pcols)
  real(r8) :: s_bctend(pcols,pver), q_bctend(pcols,pver), safter, qafter
  real(r8) :: yref(outputlength,pcols), ycheck(outputlength,pcols), err
  integer :: i, k, ncol, step, u
  integer(8) :: t0, t1, rate
  ncol = pcols
  open(newunit=u, file="cam_state.bin", access="stream", form="unformatted")
  read(u) t; read(u) q; read(u) ps; read(u) solin; read(u) lhflx; read(u) shflx; read(u) coszrs; close(u)
  open(newunit=u, file="cam_norm.bin", access="stream", form="unformatted")
  read(u) in_mean; read(u) in_max; read(u) in_min; read(u) out_scale; close(u)
  open(newunit=u, file="cam_ref.bin", access="stream", form="unformatted"); read(u) yref; close(u)

  call system_clock(t0, rate)
  do step = 1, nsteps
    ! ---- E3SM: pack the NN input from the physics state
    input(:ncol,0*pver+1:1*pver) = t(1:ncol,1:pver)          ! state_t
    input(:ncol,1*pver+1:2*pver) = q(1:ncol,1:pver)          ! state_q0001
    input(:ncol,2*pver+1) = ps(1:ncol)                       ! state_ps
    input(:ncol,2*pver+2) = solin(1:ncol)                    ! pbuf_SOLIN
    input(:ncol,2*pver+3) = lhflx(1:ncol)                    ! pbuf_LHFLX
    input(:ncol,2*pver+4) = shflx(1:ncol)                    ! pbuf_SHFLX
    ! ---- E3SM: input normalization
    do i = 1, ncol
      do k = 1, inputlength
        input(i,k) = (input(i,k) - in_mean(k)) / (in_max(k) - in_min(k))
      end do
    end do
    ! ---- E3SM: do the torch inference
    input_torch(:,:) = 0.
    do i = 1, ncol
      do k = 1, inputlength
        input_torch(k,i) = input(i,k)
      end do
    end do
    call mlp_forward(input_torch, output_torch)
    do i = 1, ncol
      do k = 1, outputlength
        output(i,k) = output_torch(k,i)
      end do
    end do
    ! ---- E3SM: output de-scaling
    do i = 1, ncol
      do k = 1, outputlength
        output(i,k) = output(i,k) / out_scale(k)
      end do
    end do
    if (step == nsteps) then
      do i = 1, ncol
        do k = 1, outputlength
          ycheck(k,i) = output(i,k) * out_scale(k)
        end do
      end do
    end if
    ! ---- E3SM: post processing, non-negative constraints
    do i = 1, ncol
      do k = outputlength-7, outputlength
        output(i,k) = max(output(i,k), 0.)
      end do
      if (coszrs(i) .le. 0.) then
        output(i,2*pver+1) = 0. ! netsw
        output(i,2*pver+5) = 0. ! sols
        output(i,2*pver+6) = 0. ! soll
        output(i,2*pver+7) = 0. ! solsd
        output(i,2*pver+8) = 0. ! solld
      endif
    end do
    ! ---- E3SM: NN output to atmosphere forcing
    s_bctend(:ncol,1:pver) = output(1:ncol,0*pver+1:1*pver)*cpair
    q_bctend(:ncol,1:pver) = output(1:ncol,1*pver+1:2*pver)
    ! ---- E3SM: atmos positivity constraints
    do i = 1, ncol
      do k = 1, pver
        safter = t(i,k)*cpair + s_bctend(i,k)*ztodt
        if (safter .lt. 0.) s_bctend(i,k) = s_bctend(i,k) + abs(safter)/ztodt
        qafter = q(i,k) + q_bctend(i,k)*ztodt
        if (qafter .lt. 0.) q_bctend(i,k) = q_bctend(i,k) + abs(qafter)/ztodt
      end do
    end do
  end do
  call system_clock(t1)

  err = maxval(abs(ycheck - yref)) / maxval(abs(yref))
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'checksum:', sum(output), '  max rel err (model out):', err, '  s_bctend(1,1):', s_bctend(1,1)
end program cam_host
