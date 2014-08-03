; audio2spectrum takes an audio file in .WAV format and generates
; a video file with a spectrum (FFT) of the audio file
; Arguments:
;   filename - the full pathname of a valid .WAV file
;   res - two element vector specifying resolution of output video
; Usage:
;   Invoke with IDL> audio2spectrum, 'foo.wav', [3840,2160]

pro audio2spectrum, filename, res
  compile_opt idl2
  
  tic
  ; if the filename is left undefined, use a default file
  if (n_elements(filename) eq 0) then begin
    filename = file_dirname(routine_filepath())+path_sep()+'default.wav'
    print, filename
  endif
  if (n_elements(res) ne 2) then begin
    res = [1920,1080]
  endif
  query = query_wav(filename,fileinfo)
  if (query ne 1) then begin
    print, 'Invalid file. Please provide full path to a valid .WAV file.'
    return
  endif else begin
    VFR = 30 ; video frame rate
    ASR = fileinfo.SAMPLES_PER_SEC ; audio sample rate
    ACH = fileinfo.CHANNELS ; audio channel count
    ABD = fileinfo.BITS_PER_SAMPLE ; audio bit depth
    print, 'Valid file. Channels:', strtrim(ACH,2), $
           ' SR:', strtrim(ASR,2), $
           ' BD:', strtrim(ABD,2)
    if ACH eq 1 then begin
      print, 'Please use a stereo .WAV file'
      return
    endif
  endelse
  
  ; get a video object
  videoObj = idlffvideowrite('waveform.mp4')
  videoStream = videoObj.addvideostream(res[0],res[1],VFR)
  
  ; read in the WAV data and normalize to [-1,1]
  raw = read_wav(filename,samplerate)
  data = double(raw/2.0^15)
  
  ; get limits/dimensions
  audiosamps = n_elements(data[0,*])
  audiolen = audiosamps/ASR
  wsize = 16384 ; FFT window length
  print, 'Audio length: ', strtrim(audiolen,2), 's (', strtrim(floor(audiolen/60),2), ':', string(audiolen MOD 60, format='(I02)'), ')'
  frametotal = VFR*audiolen
  print, 'Total frames to generate: ', strtrim(frametotal,2)
  print, 'Samples per frame: ', strtrim(ASR/VFR,2)
  yb = [max(data[0,*],submax),min(data[0,*],submin)] ; find max/min subscripts
  subabs = data[0,submax] gt abs(data[0,submin]) ? submax : submin
  subabs = subabs gt audiosamps-wsize ? subabs-wsize/2-1 : subabs
  subabs = subabs lt wsize ? wsize/2 : subabs
  ; set plot limits from max window (not entirely accurate)
  ylim = max((abs(fft(data[0,subabs-wsize/2:subabs+wsize/2+1])))[1:wsize/2])*2.0
  
  ; below, we are indexing at a window at "playhead" plus window,
  ; so we correct the alignment here by prepending a fraction of the window
  data = [[make_array(ACH,ceil(wsize*0.50),/double)],[data]]
  
  ; switch to Z buffer for off-screen rendering
  set_plot, 'Z'
  device, set_resolution=res, set_pixel_depth=24, decomposed=1
  erase
  
  ; create frames ---------------------------------------------------
  for i=0,frametotal-1-ceil(wsize/float(ASR/VFR)) do begin
    plot, (abs(fft(data[0,i*(ASR/VFR):i*(ASR/VFR)+wsize])))[1:wsize/2]*findgen(wsize/2-1,increment=0.003,start=1), $
      thick=ceil(res[1]/320.0), background='000000'xL, color='ffff00'xL, position=[0,0.5,1,1], $
      yrange=[0,ylim], xstyle=4, ystyle=4, /xlog, xrange=[10,(ASR/VFR)/2];, psym=10
    plot, -(abs(fft(data[1,i*(ASR/VFR):i*(ASR/VFR)+wsize])))[1:wsize/2]*findgen(wsize/2-1,increment=0.003,start=1), $
      thick=ceil(res[1]/320.0), background='000000'xL, color='00ffff'xL, position=[0,0,1,0.5], $
      yrange=[-ylim,0], xstyle=4, ystyle=4, /xlog, xrange=[10,(ASR/VFR)/2], $
      /noerase;, psym=10
    frame = tvrd(true=1)
    ; apply visual effects to the generated frame
    frame[0,*,*] = median(smooth(reform(frame[0,*,*]),1),4)
    frame[1,*,*] = median(smooth(reform(frame[1,*,*]),1),3)
    frame[2,*,*] = median(smooth(reform(frame[2,*,*]),1),4)
    
    ; calculate progress and remaining time
    progress = float(i)/(frametotal)
    remaining = toc()/(progress+0.001)-toc()
    !PROMPT='Progress: '+strtrim(floor(100*progress),2)+'% (remaining: '+strtrim(floor(remaining/60),2)+':'+string(remaining MOD 60, format='(I02)')+')'
    !NULL = videoObj.put(videostream, frame)
  endfor
  ; end create frames -----------------------------------------------
  !PROMPT='IDL>' ; reset prompt
  
  ; close the file
  videoObj.cleanup
  
  finished = toc()
  print, 'Sucessful video generation, finished in ', strtrim(finished,2), 's (', strtrim(floor(finished/60),2), ':', string(finished MOD 60, format='(I02)'), ')'
  
end
