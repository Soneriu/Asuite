::for /r . %%d in (__history) do @if exist "%%d" rd /Q /S "%%d"
del /S /Q *.tvsconfig
del /S /Q *.identcache
del /S /Q *.local
del /S /Q *.2007
del /S /Q *.???_
del /S /Q *.~*
del /S /Q *.bak
del /S /Q *.bk?
del /S /Q *.cfg
del /S /Q *.dcu
del /S /Q *.ddp
del /S /Q *.dof
del /S /Q *.dpu
del /S /Q *.drc
del /S /Q *.dsk
del /S /Q *.elf
del /S /Q *.kof
del /S /Q *.log
del /S /Q *.mad
del /S /Q *.map
del /S /Q *.mes
del /S /Q *.mps
del /S /Q *.mpt
del /S /Q *.prf
del /S /Q *.stat
del /S /Q *.tci
del /S /Q *.tmp
del /S /Q log.txt
del /S /Q *.exe
