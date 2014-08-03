; audio2wave takes an audio file in .WAV format and generates
; a video file with a waveform of the audio file
; Arguments:
;   filename - the full pathname of a valid .WAV file
;   res - two element vector specifying resolution of output video
; Usage:
;   Invoke with IDL> audio2wave, 'foo.wav', [3840,2160]

pro audio2wave, filename, res
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
  endelse
  
  ; get a video object
  videoObj = idlffvideowrite('waveform.mp4')
  videoStream = videoObj.addvideostream(res[0],res[1],VFR)
  
  ; read in the WAV data and normalize to [-1,1]
  raw = read_wav(filename,samplerate)
  data = double(raw/2.0^15)
  
  ; get limits/dimensions
  audiolen = (ACH eq 2)?(n_elements(data[0,*])/ASR):(n_elements(data)/ASR)
  print, 'Audio length: ', strtrim(audiolen,2), 's'
  frametotal = VFR*audiolen
  print, 'Total frames to generate: ', strtrim(frametotal,2)
  print, 'Samples per frame: ', strtrim(ASR/VFR,2)
  yb = [max(data),min(data)]
  ylim = (yb[0]>yb[1]?yb[0]:yb[1]) ; to set plot limits
  
  ; switch to Z buffer for off-screen rendering
  set_plot, 'Z'
  device, set_resolution=res, set_pixel_depth=24, decomposed=1
  erase
  
  ; create frames ---------------------------------------------------
  for i=0,frametotal-1 do begin
    if (ACH eq 2) then begin
      plot, data[0,i*(ASR/VFR):(i+1)*(ASR/VFR)], thick=6, $
        max_value=1, min_value=-1, background='000000'xL, $
        color='0000ff'xL, position=[0,0.5,1,1], $
        yrange=[-ylim,ylim], xstyle=4, ystyle=4
      plot, data[0,i*(ASR/VFR):(i+1)*(ASR/VFR)], thick=6, $
        max_value=1, min_value=-1, background='000000'xL, $
        color='ff4000'xL, position=[0,0,1,0.5], $
        yrange=[-ylim,ylim], xstyle=4, ystyle=4, $
        /noerase
    endif else begin
      plot, data[i*(ASR/VFR):(i+1)*(ASR/VFR)], thick=6, $
        max_value=1, min_value=-1, background='000000'xL, $
        color='ff8000'xL, position=[0,0,1,1], $
        yrange=[-ylim,ylim], xstyle=4, ystyle=4
    endelse
    frame = tvrd(true=1)
    !PROMPT='Progress: '+strtrim(floor(100*i/(frametotal-1)),2)+'%'
    !NULL = videoObj.put(videostream, frame)
  endfor
  ; end create frames -----------------------------------------------
  !PROMPT='IDL>' ; reset prompt
  
  ; close the file
  videoObj.cleanup
  
  print, 'Sucessful video generation, finished in ', strtrim(toc(),2), 's'
end
