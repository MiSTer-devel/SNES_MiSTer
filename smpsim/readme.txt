SPCSIM
======

Simulates S-SMP and S-DSP via ghdl. Outputs either a waveform or raw PCM audio file from an SPC source.

Building (requires GHDL):
# make

Just run the testbench and create a raw PCM .AUD file (32k/stereo/16bits/sample) from SNES.SPC:

# make run

Creating a .GHW file for examining e.g. in GtkWave:

# make wave

Converting the resulting snes.aud file to snes.wav (requires ffmpeg):

# make aud
