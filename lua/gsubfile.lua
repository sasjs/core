local fpath, outpath, file, fcontent

-- configure in / out paths
fpath = sas.symget("file")
outpath = sas.symget("outfile")
if ( outpath == 0 )
then
   outpath=fpath
end

-- open file and perform the substitution
file = io.open(fpath,"r")
fcontent = file:read("*all")
file:close()
fcontent = string.gsub(
  fcontent,
  sas.symget(sas.symget("patternvar")),
  sas.symget(sas.symget("replacevar"))
)

-- write the file back out
file = io.open(outpath, "w+")
io.output(file)
io.write(fcontent)
io.close(file)