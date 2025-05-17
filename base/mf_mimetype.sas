/**
  @file
  @brief Returns a mime type from a file extension
  @details Provide a file extension and get a mime type.
    The mappings were derived from this source:
    https://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types



  @param [in] ext The file extension (unquoted)
  @return output The mime type

  @version 9.2
  @author Allan Bowe
**/

%macro mf_mimetype(
    ext
)/*/STORE SOURCE*/ /minoperator mindelimiter=' ';

%let ext=%lowcase(&ext);

%if &ext in (sas txt text conf def list log)
%then %do;%str(text/plain)%end;
%else %if &ext=xlsx %then %do;
%str(application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)%end;
%else %if &ext in (xls xlm xla xlc xlt xlw)
%then %do;%str(application/vnd.ms-excel)%end;
%else %if &ext=xlsm
%then %do;%str(application/vnd.ms-excel.sheet.macroenabled.12)%end;
%else %if &ext=xlsb
%then %do;%str(application/vnd.ms-excel.sheet.binary.macroenabled.12)%end;
%else %if &ext in (css csv html n3 sgml vcard)
%then %do;%str(text/&ext)%end;
%else %if &ext in (avif bmp cgm gif ief jxl ktx png sgi tiff webp)
%then %do;%str(image/&ext)%end;
%else %if &ext in (exi gxf ipfix json mbox mp21 mxf oda oxps pdf rtf sdp wasm
  xml yang zip)
%then %do;%str(application/&ext)%end;
%else %if &ext in (jpeg jpg jpe) %then %do;%str(image/jpeg)%end;
%else %if &ext in (mp4 mp4v mpg4) %then %do;%str(video/mp4)%end;
%else %if &ext in (otf ttf woff woff2) %then %do;%str(font/&ext)%end;
%else %if &ext in (mpeg mpg mpe m1v m2v)
%then %do;%str(video/mpeg)%end;
%else %if &ext in (h261 h263 h264 jpm mj2 webm)
%then %do;%str(video/&ext)%end;
%else %if &ext in (f4v fli flv m4v mng smv)
%then %do;%str(video/x-&ext)%end;
%else %if &ext in (3ds cmx pcx rgb tga)
%then %do;%str(image/x-&ext)%end;
%else %if &ext in (asm nfo opml sfv)
%then %do;%str(text/x-&ext)%end;
%else %if &ext in (aac caf flac wav)
%then %do;%str(audio/x-&ext)%end;
%else %if &ext in (ts m2t m2ts mts)
%then %do;%str(video/mp2t)%end;
%else %if &ext in (pfa pfb pfm afm)
%then %do;%str(application/x-font-type1)%end;
%else %if &ext in (oga ogg spx opus)
%then %do;%str(audio/ogg)%end;
%else %if &ext in (mid midi kar rmi)
%then %do;%str(audio/midi)%end;
%else %if &ext in (onetoc onetoc2 onetmp onepkg)
%then %do;%str(application/onenote)%end;
%else %if &ext in (mxml xhvml xvml xvm)
%then %do;%str(application/xv+xml)%end;
%else %if &ext in (f for f77 f90)
%then %do;%str(text/x-fortran)%end;
%else %if &ext in (wmf wmz emf emz)
%then %do;%str(application/x-msmetafile)%end;
%else %if &ext in (exe dll com bat msi)
%then %do;%str(application/x-msdownload)%end;
%else %if &ext in (bin dms lrf mar so dist distz pkg bpk dump elc deploy)
%then %do;%str(application/octet-stream)%end;
%else %if &ext in (atom atomcat atomsvc ccxml davmount emma gml gpx inkml mads
  mathml metalink mets mods omdoc pls rdf rsd rss sbml shf smil sru ssdl ssml
  tei wsdl wspolicy xaml xenc xhtml xop xslt xspf yin)
%then %do;%str(application/&ext+xml)%end;
%else %if &ext in (dir dcr dxr cst cct cxt w3d fgd swa)
%then %do;%str(application/x-director)%end;
%else %if &ext in (z1 z2 z3 z4 z5 z6 z7 z8)
%then %do;%str(application/x-zmachine)%end;
%else %if &ext in (c cc cxx cpp h hh dic)
%then %do;%str(text/x-c)%end;
%else %if &ext in (mpga mp2 mp2a mp3 m2a m3a)
%then %do;%str(audio/mpeg)%end;
%else %if &ext in (t tr roff man me ms)
%then %do;%str(text/troff)%end;
%else %if &ext in (cbr cba cbt cbz cb7)
%then %do;%str(application/x-cbr)%end;
%else %if &ext in (fh fhc fh4 fh5 fh7)
%then %do;%str(image/x-freehand)%end;
%else %if &ext in (aab x32 u32 vox)
%then %do;%str(application/x-authorware-bin)%end;
%else %if &ext in (uvi uvvi uvg uvvg)
%then %do;%str(image/vnd.dece.graphic)%end;
%else %if &ext in (cdx cif cmdf cml csml xyz)
%then %do;%str(chemical/x-&ext)%end;
%else %if &ext in (aif aiff aifc) %then %do;%str(audio/x-aiff)%end;
%else %if &ext in (ma nb mb) %then %do;%str(application/mathematica)%end;
%else %if &ext in (mvb m13 m14) %then %do;%str(application/x-msmediaview)%end;
%else %if &ext in (msh mesh silo) %then %do;%str(model/mesh)%end;
%else %if &ext in (uri uris urls) %then %do;%str(text/uri-list)%end;
%else %if &ext in (mkv mk3d mks) %then %do;%str(video/x-matroska)%end;
%else %if &ext=ez %then %do;%str(application/andrew-inset)%end;
%else %if &ext=aw %then %do;%str(application/applixware)%end;
%else %if &ext=cdmia %then %do;%str(application/cdmi-capability)%end;
%else %if &ext=cdmic %then %do;%str(application/cdmi-container)%end;
%else %if &ext=cdmid %then %do;%str(application/cdmi-domain)%end;
%else %if &ext=cdmio %then %do;%str(application/cdmi-object)%end;
%else %if &ext=cdmiq %then %do;%str(application/cdmi-queue)%end;
%else %if &ext=cu %then %do;%str(application/cu-seeme)%end;
%else %if &ext=dssc %then %do;%str(application/dssc+der)%end;
%else %if &ext=xdssc %then %do;%str(application/dssc+xml)%end;
%else %if &ext=ecma %then %do;%str(application/ecmascript)%end;
%else %if &ext=epub %then %do;%str(application/epub+zip)%end;
%else %if &ext=pfr %then %do;%str(application/font-tdpfr)%end;
%else %if &ext=stk %then %do;%str(application/hyperstudio)%end;
%else %if &ext=ink %then %do;%str(application/inkml+xml)%end;
%else %if &ext=jar %then %do;%str(application/java-archive)%end;
%else %if &ext=ser %then %do;%str(application/java-serialized-object)%end;
%else %if &ext=class %then %do;%str(application/java-vm)%end;
%else %if &ext=jsonml %then %do;%str(application/jsonml+json)%end;
%else %if &ext=lostxml %then %do;%str(application/lost+xml)%end;
%else %if &ext=hqx %then %do;%str(application/mac-binhex40)%end;
%else %if &ext=cpt %then %do;%str(application/mac-compactpro)%end;
%else %if &ext=mrc %then %do;%str(application/marc)%end;
%else %if &ext=mrcx %then %do;%str(application/marcxml+xml)%end;
%else %if &ext=mscml %then %do;%str(application/mediaservercontrol+xml)%end;
%else %if &ext=meta4 %then %do;%str(application/metalink4+xml)%end;
%else %if &ext=m21 %then %do;%str(application/mp21)%end;
%else %if &ext=mp4s %then %do;%str(application/mp4)%end;
%else %if &ext=doc %then %do;%str(application/msword)%end;
%else %if &ext=dot %then %do;%str(application/msword)%end;
%else %if &ext=opf %then %do;%str(application/oebps-package+xml)%end;
%else %if &ext=ogx %then %do;%str(application/ogg)%end;
%else %if &ext=xer %then %do;%str(application/patch-ops-error+xml)%end;
%else %if &ext=pgp %then %do;%str(application/pgp-encrypted)%end;
%else %if &ext=asc %then %do;%str(application/pgp-signature)%end;
%else %if &ext=sig %then %do;%str(application/pgp-signature)%end;
%else %if &ext=prf %then %do;%str(application/pics-rules)%end;
%else %if &ext=p10 %then %do;%str(application/pkcs10)%end;
%else %if &ext=p7m %then %do;%str(application/pkcs7-mime)%end;
%else %if &ext=p7c %then %do;%str(application/pkcs7-mime)%end;
%else %if &ext=p7s %then %do;%str(application/pkcs7-signature)%end;
%else %if &ext=p8 %then %do;%str(application/pkcs8)%end;
%else %if &ext=ac %then %do;%str(application/pkix-attr-cert)%end;
%else %if &ext=cer %then %do;%str(application/pkix-cert)%end;
%else %if &ext=crl %then %do;%str(application/pkix-crl)%end;
%else %if &ext=pkipath %then %do;%str(application/pkix-pkipath)%end;
%else %if &ext=pki %then %do;%str(application/pkixcmp)%end;
%else %if &ext=cww %then %do;%str(application/prs.cww)%end;
%else %if &ext=pskcxml %then %do;%str(application/pskc+xml)%end;
%else %if &ext=rif %then %do;%str(application/reginfo+xml)%end;
%else %if &ext=rnc %then %do;%str(application/relax-ng-compact-syntax)%end;
%else %if &ext=rld %then %do;%str(application/resource-lists-diff+xml)%end;
%else %if &ext=rl %then %do;%str(application/resource-lists+xml)%end;
%else %if &ext=gbr %then %do;%str(application/rpki-ghostbusters)%end;
%else %if &ext=mft %then %do;%str(application/rpki-manifest)%end;
%else %if &ext=roa %then %do;%str(application/rpki-roa)%end;
%else %if &ext=scq %then %do;%str(application/scvp-cv-request)%end;
%else %if &ext=scs %then %do;%str(application/scvp-cv-response)%end;
%else %if &ext=spq %then %do;%str(application/scvp-vp-request)%end;
%else %if &ext=spp %then %do;%str(application/scvp-vp-response)%end;
%else %if &ext=setpay %then %do;%str(application/set-payment-initiation)%end;
%else %if &ext=setreg %then %do;%str(application/set-registration-initiation)%end;
%else %if &ext=smi %then %do;%str(application/smil+xml)%end;
%else %if &ext=rq %then %do;%str(application/sparql-query)%end;
%else %if &ext=srx %then %do;%str(application/sparql-results+xml)%end;
%else %if &ext=gram %then %do;%str(application/srgs)%end;
%else %if &ext=grxml %then %do;%str(application/srgs+xml)%end;
%else %if &ext=teicorpus %then %do;%str(application/tei+xml)%end;
%else %if &ext=tfi %then %do;%str(application/thraud+xml)%end;
%else %if &ext=tsd %then %do;%str(application/timestamped-data)%end;
%else %if &ext=vxml %then %do;%str(application/voicexml+xml)%end;
%else %if &ext=wgt %then %do;%str(application/widget)%end;
%else %if &ext=hlp %then %do;%str(application/winhlp)%end;
%else %if &ext=7z %then %do;%str(application/x-7z-compressed)%end;
%else %if &ext=abw %then %do;%str(application/x-abiword)%end;
%else %if &ext=ace %then %do;%str(application/x-ace-compressed)%end;
%else %if &ext=dmg %then %do;%str(application/x-apple-diskimage)%end;
%else %if &ext=aam %then %do;%str(application/x-authorware-map)%end;
%else %if &ext=aas %then %do;%str(application/x-authorware-seg)%end;
%else %if &ext=bcpio %then %do;%str(application/x-bcpio)%end;
%else %if &ext=torrent %then %do;%str(application/x-bittorrent)%end;
%else %if &ext=blb %then %do;%str(application/x-blorb)%end;
%else %if &ext=blorb %then %do;%str(application/x-blorb)%end;
%else %if &ext=bz %then %do;%str(application/x-bzip)%end;
%else %if &ext=bz2 %then %do;%str(application/x-bzip2)%end;
%else %if &ext=boz %then %do;%str(application/x-bzip2)%end;
%else %if &ext=vcd %then %do;%str(application/x-cdlink)%end;
%else %if &ext=cfs %then %do;%str(application/x-cfs-compressed)%end;
%else %if &ext=chat %then %do;%str(application/x-chat)%end;
%else %if &ext=pgn %then %do;%str(application/x-chess-pgn)%end;
%else %if &ext=nsc %then %do;%str(application/x-conference)%end;
%else %if &ext=cpio %then %do;%str(application/x-cpio)%end;
%else %if &ext=csh %then %do;%str(application/x-csh)%end;
%else %if &ext=deb %then %do;%str(application/x-debian-package)%end;
%else %if &ext=udeb %then %do;%str(application/x-debian-package)%end;
%else %if &ext=dgc %then %do;%str(application/x-dgc-compressed)%end;
%else %if &ext=wad %then %do;%str(application/x-doom)%end;
%else %if &ext=ncx %then %do;%str(application/x-dtbncx+xml)%end;
%else %if &ext=dtb %then %do;%str(application/x-dtbook+xml)%end;
%else %if &ext=res %then %do;%str(application/x-dtbresource+xml)%end;
%else %if &ext=dvi %then %do;%str(application/x-dvi)%end;
%else %if &ext=evy %then %do;%str(application/x-envoy)%end;
%else %if &ext=eva %then %do;%str(application/x-eva)%end;
%else %if &ext=bdf %then %do;%str(application/x-font-bdf)%end;
%else %if &ext=gsf %then %do;%str(application/x-font-ghostscript)%end;
%else %if &ext=psf %then %do;%str(application/x-font-linux-psf)%end;
%else %if &ext=pcf %then %do;%str(application/x-font-pcf)%end;
%else %if &ext=snf %then %do;%str(application/x-font-snf)%end;
%else %if &ext=arc %then %do;%str(application/x-freearc)%end;
%else %if &ext=spl %then %do;%str(application/x-futuresplash)%end;
%else %if &ext=gca %then %do;%str(application/x-gca-compressed)%end;
%else %if &ext=ulx %then %do;%str(application/x-glulx)%end;
%else %if &ext=gnumeric %then %do;%str(application/x-gnumeric)%end;
%else %if &ext=gramps %then %do;%str(application/x-gramps-xml)%end;
%else %if &ext=gtar %then %do;%str(application/x-gtar)%end;
%else %if &ext=hdf %then %do;%str(application/x-hdf)%end;
%else %if &ext=install %then %do;%str(application/x-install-instructions)%end;
%else %if &ext=iso %then %do;%str(application/x-iso9660-image)%end;
%else %if &ext=jnlp %then %do;%str(application/x-java-jnlp-file)%end;
%else %if &ext=latex %then %do;%str(application/x-latex)%end;
%else %if &ext=lzh %then %do;%str(application/x-lzh-compressed)%end;
%else %if &ext=lha %then %do;%str(application/x-lzh-compressed)%end;
%else %if &ext=mie %then %do;%str(application/x-mie)%end;
%else %if &ext=prc %then %do;%str(application/x-mobipocket-ebook)%end;
%else %if &ext=mobi %then %do;%str(application/x-mobipocket-ebook)%end;
%else %if &ext=application %then %do;%str(application/x-ms-application)%end;
%else %if &ext=lnk %then %do;%str(application/x-ms-shortcut)%end;
%else %if &ext=wmd %then %do;%str(application/x-ms-wmd)%end;
%else %if &ext=wmz %then %do;%str(application/x-ms-wmz)%end;
%else %if &ext=xbap %then %do;%str(application/x-ms-xbap)%end;
%else %if &ext=mdb %then %do;%str(application/x-msaccess)%end;
%else %if &ext=obd %then %do;%str(application/x-msbinder)%end;
%else %if &ext=crd %then %do;%str(application/x-mscardfile)%end;
%else %if &ext=clp %then %do;%str(application/x-msclip)%end;
%else %if &ext=mny %then %do;%str(application/x-msmoney)%end;
%else %if &ext=pub %then %do;%str(application/x-mspublisher)%end;
%else %if &ext=scd %then %do;%str(application/x-msschedule)%end;
%else %if &ext=trm %then %do;%str(application/x-msterminal)%end;
%else %if &ext=wri %then %do;%str(application/x-mswrite)%end;
%else %if &ext=nc %then %do;%str(application/x-netcdf)%end;
%else %if &ext=cdf %then %do;%str(application/x-netcdf)%end;
%else %if &ext=nzb %then %do;%str(application/x-nzb)%end;
%else %if &ext=p12 %then %do;%str(application/x-pkcs12)%end;
%else %if &ext=pfx %then %do;%str(application/x-pkcs12)%end;
%else %if &ext=p7b %then %do;%str(application/x-pkcs7-certificates)%end;
%else %if &ext=spc %then %do;%str(application/x-pkcs7-certificates)%end;
%else %if &ext=p7r %then %do;%str(application/x-pkcs7-certreqresp)%end;
%else %if &ext=rar %then %do;%str(application/x-rar-compressed)%end;
%else %if &ext=ris %then %do;%str(application/x-research-info-systems)%end;
%else %if &ext=sh %then %do;%str(application/x-sh)%end;
%else %if &ext=shar %then %do;%str(application/x-shar)%end;
%else %if &ext=swf %then %do;%str(application/x-shockwave-flash)%end;
%else %if &ext=xap %then %do;%str(application/x-silverlight-app)%end;
%else %if &ext=sql %then %do;%str(application/x-sql)%end;
%else %if &ext=sit %then %do;%str(application/x-stuffit)%end;
%else %if &ext=sitx %then %do;%str(application/x-stuffitx)%end;
%else %if &ext=srt %then %do;%str(application/x-subrip)%end;
%else %if &ext=sv4cpio %then %do;%str(application/x-sv4cpio)%end;
%else %if &ext=sv4crc %then %do;%str(application/x-sv4crc)%end;
%else %if &ext=t3 %then %do;%str(application/x-t3vm-image)%end;
%else %if &ext=gam %then %do;%str(application/x-tads)%end;
%else %if &ext=tar %then %do;%str(application/x-tar)%end;
%else %if &ext=tcl %then %do;%str(application/x-tcl)%end;
%else %if &ext=tex %then %do;%str(application/x-tex)%end;
%else %if &ext=tfm %then %do;%str(application/x-tex-tfm)%end;
%else %if &ext=texinfo %then %do;%str(application/x-texinfo)%end;
%else %if &ext=texi %then %do;%str(application/x-texinfo)%end;
%else %if &ext=obj %then %do;%str(application/x-tgif)%end;
%else %if &ext=ustar %then %do;%str(application/x-ustar)%end;
%else %if &ext=src %then %do;%str(application/x-wais-source)%end;
%else %if &ext=der %then %do;%str(application/x-x509-ca-cert)%end;
%else %if &ext=crt %then %do;%str(application/x-x509-ca-cert)%end;
%else %if &ext=fig %then %do;%str(application/x-xfig)%end;
%else %if &ext=xlf %then %do;%str(application/x-xliff+xml)%end;
%else %if &ext=xpi %then %do;%str(application/x-xpinstall)%end;
%else %if &ext=xz %then %do;%str(application/x-xz)%end;
%else %if &ext=xdf %then %do;%str(application/xcap-diff+xml)%end;
%else %if &ext=xht %then %do;%str(application/xhtml+xml)%end;
%else %if &ext=xsl %then %do;%str(application/xml)%end;
%else %if &ext=dtd %then %do;%str(application/xml-dtd)%end;
%else %if &ext=xpl %then %do;%str(application/xproc+xml)%end;
%else %if &ext=adp %then %do;%str(audio/adpcm)%end;
%else %if &ext=au %then %do;%str(audio/basic)%end;
%else %if &ext=snd %then %do;%str(audio/basic)%end;
%else %if &ext=m4a %then %do;%str(audio/mp4)%end;
%else %if &ext=mp4a %then %do;%str(audio/mp4)%end;
%else %if &ext=s3m %then %do;%str(audio/s3m)%end;
%else %if &ext=sil %then %do;%str(audio/silk)%end;
%else %if &ext=uva %then %do;%str(audio/vnd.dece.audio)%end;
%else %if &ext=uvva %then %do;%str(audio/vnd.dece.audio)%end;
%else %if &ext=eol %then %do;%str(audio/vnd.digital-winds)%end;
%else %if &ext=dra %then %do;%str(audio/vnd.dra)%end;
%else %if &ext=dts %then %do;%str(audio/vnd.dts)%end;
%else %if &ext=dtshd %then %do;%str(audio/vnd.dts.hd)%end;
%else %if &ext=lvp %then %do;%str(audio/vnd.lucent.voice)%end;
%else %if &ext=pya %then %do;%str(audio/vnd.ms-playready.media.pya)%end;
%else %if &ext=ecelp4800 %then %do;%str(audio/vnd.nuera.ecelp4800)%end;
%else %if &ext=ecelp7470 %then %do;%str(audio/vnd.nuera.ecelp7470)%end;
%else %if &ext=ecelp9600 %then %do;%str(audio/vnd.nuera.ecelp9600)%end;
%else %if &ext=rip %then %do;%str(audio/vnd.rip)%end;
%else %if &ext=weba %then %do;%str(audio/webm)%end;
%else %if &ext=mka %then %do;%str(audio/x-matroska)%end;
%else %if &ext=m3u %then %do;%str(audio/x-mpegurl)%end;
%else %if &ext=wax %then %do;%str(audio/x-ms-wax)%end;
%else %if &ext=wma %then %do;%str(audio/x-ms-wma)%end;
%else %if &ext=ra %then %do;%str(audio/x-pn-realaudio)%end;
%else %if &ext=ram %then %do;%str(audio/x-pn-realaudio)%end;
%else %if &ext=rmp %then %do;%str(audio/x-pn-realaudio-plugin)%end;
%else %if &ext=xm %then %do;%str(audio/xm)%end;
%else %if &ext=ttc %then %do;%str(font/collection)%end;
%else %if &ext=g3 %then %do;%str(image/g3fax)%end;
%else %if &ext=btif %then %do;%str(image/prs.btif)%end;
%else %if &ext=svg %then %do;%str(image/svg+xml)%end;
%else %if &ext=svgz %then %do;%str(image/svg+xml)%end;
%else %if &ext=tif %then %do;%str(image/tiff)%end;
%else %if &ext=psd %then %do;%str(image/vnd.adobe.photoshop)%end;
%else %if &ext=djv %then %do;%str(image/vnd.djvu)%end;
%else %if &ext=djvu %then %do;%str(image/vnd.djvu)%end;
%else %if &ext=sub %then %do;%str(image/vnd.dvb.subtitle)%end;
%else %if &ext=dwg %then %do;%str(image/vnd.dwg)%end;
%else %if &ext=dxf %then %do;%str(image/vnd.dxf)%end;
%else %if &ext=fbs %then %do;%str(image/vnd.fastbidsheet)%end;
%else %if &ext=fpx %then %do;%str(image/vnd.fpx)%end;
%else %if &ext=fst %then %do;%str(image/vnd.fst)%end;
%else %if &ext=mmr %then %do;%str(image/vnd.fujixerox.edmics-mmr)%end;
%else %if &ext=rlc %then %do;%str(image/vnd.fujixerox.edmics-rlc)%end;
%else %if &ext=mdi %then %do;%str(image/vnd.ms-modi)%end;
%else %if &ext=wdp %then %do;%str(image/vnd.ms-photo)%end;
%else %if &ext=npx %then %do;%str(image/vnd.net-fpx)%end;
%else %if &ext=wbmp %then %do;%str(image/vnd.wap.wbmp)%end;
%else %if &ext=xif %then %do;%str(image/vnd.xiff)%end;
%else %if &ext=ras %then %do;%str(image/x-cmu-raster)%end;
%else %if &ext=ico %then %do;%str(image/x-icon)%end;
%else %if &ext=sid %then %do;%str(image/x-mrsid-image)%end;
%else %if &ext=pct %then %do;%str(image/x-pict)%end;
%else %if &ext=pic %then %do;%str(image/x-pict)%end;
%else %if &ext=pnm %then %do;%str(image/x-portable-anymap)%end;
%else %if &ext=pbm %then %do;%str(image/x-portable-bitmap)%end;
%else %if &ext=pgm %then %do;%str(image/x-portable-graymap)%end;
%else %if &ext=ppm %then %do;%str(image/x-portable-pixmap)%end;
%else %if &ext=xbm %then %do;%str(image/x-xbitmap)%end;
%else %if &ext=xpm %then %do;%str(image/x-xpixmap)%end;
%else %if &ext=xwd %then %do;%str(image/x-xwindowdump)%end;
%else %if &ext=eml %then %do;%str(message/rfc822)%end;
%else %if &ext=mime %then %do;%str(message/rfc822)%end;
%else %if &ext=iges %then %do;%str(model/iges)%end;
%else %if &ext=igs %then %do;%str(model/iges)%end;
%else %if &ext=dae %then %do;%str(model/vnd.collada+xml)%end;
%else %if &ext=dwf %then %do;%str(model/vnd.dwf)%end;
%else %if &ext=gdl %then %do;%str(model/vnd.gdl)%end;
%else %if &ext=gtw %then %do;%str(model/vnd.gtw)%end;
%else %if &ext=vtu %then %do;%str(model/vnd.vtu)%end;
%else %if &ext=vrml %then %do;%str(model/vrml)%end;
%else %if &ext=wrl %then %do;%str(model/vrml)%end;
%else %if &ext=x3db %then %do;%str(model/x3d+binary)%end;
%else %if &ext=x3dbz %then %do;%str(model/x3d+binary)%end;
%else %if &ext=x3dv %then %do;%str(model/x3d+vrml)%end;
%else %if &ext=x3dvz %then %do;%str(model/x3d+vrml)%end;
%else %if &ext=x3d %then %do;%str(model/x3d+xml)%end;
%else %if &ext=x3dz %then %do;%str(model/x3d+xml)%end;
%else %if &ext=appcache %then %do;%str(text/cache-manifest)%end;
%else %if &ext=ics %then %do;%str(text/calendar)%end;
%else %if &ext=ifb %then %do;%str(text/calendar)%end;
%else %if &ext=htm %then %do;%str(text/html)%end;
%else %if &ext=js %then %do;%str(text/javascript)%end;
%else %if &ext=mjs %then %do;%str(text/javascript)%end;
%else %if &ext=dsc %then %do;%str(text/prs.lines.tag)%end;
%else %if &ext=rtx %then %do;%str(text/richtext)%end;
%else %if &ext=sgm %then %do;%str(text/sgml)%end;
%else %if &ext=tsv %then %do;%str(text/tab-separated-values)%end;
%else %if &ext=ttl %then %do;%str(text/turtle)%end;
%else %if &ext=curl %then %do;%str(text/vnd.curl)%end;
%else %if &ext=dcurl %then %do;%str(text/vnd.curl.dcurl)%end;
%else %if &ext=mcurl %then %do;%str(text/vnd.curl.mcurl)%end;
%else %if &ext=scurl %then %do;%str(text/vnd.curl.scurl)%end;
%else %if &ext=sub %then %do;%str(text/vnd.dvb.subtitle)%end;
%else %if &ext=fly %then %do;%str(text/vnd.fly)%end;
%else %if &ext=flx %then %do;%str(text/vnd.fmi.flexstor)%end;
%else %if &ext=gv %then %do;%str(text/vnd.graphviz)%end;
%else %if &ext=3dml %then %do;%str(text/vnd.in3d.3dml)%end;
%else %if &ext=spot %then %do;%str(text/vnd.in3d.spot)%end;
%else %if &ext=jad %then %do;%str(text/vnd.sun.j2me.app-descriptor)%end;
%else %if &ext=wml %then %do;%str(text/vnd.wap.wml)%end;
%else %if &ext=wmls %then %do;%str(text/vnd.wap.wmlscript)%end;
%else %if &ext=s %then %do;%str(text/x-asm)%end;
%else %if &ext=java %then %do;%str(text/x-java-source)%end;
%else %if &ext=p %then %do;%str(text/x-pascal)%end;
%else %if &ext=pas %then %do;%str(text/x-pascal)%end;
%else %if &ext=etx %then %do;%str(text/x-setext)%end;
%else %if &ext=uu %then %do;%str(text/x-uuencode)%end;
%else %if &ext=vcs %then %do;%str(text/x-vcalendar)%end;
%else %if &ext=vcf %then %do;%str(text/x-vcard)%end;
%else %if &ext=3gp %then %do;%str(video/3gpp)%end;
%else %if &ext=3g2 %then %do;%str(video/3gpp2)%end;
%else %if &ext=jpgv %then %do;%str(video/jpeg)%end;
%else %if &ext=jpgm %then %do;%str(video/jpm)%end;
%else %if &ext=mjp2 %then %do;%str(video/mj2)%end;
%else %if &ext=ogv %then %do;%str(video/ogg)%end;
%else %if &ext=mov %then %do;%str(video/quicktime)%end;
%else %if &ext=qt %then %do;%str(video/quicktime)%end;
%else %if &ext=uvh %then %do;%str(video/vnd.dece.hd)%end;
%else %if &ext=uvvh %then %do;%str(video/vnd.dece.hd)%end;
%else %if &ext=uvm %then %do;%str(video/vnd.dece.mobile)%end;
%else %if &ext=uvvm %then %do;%str(video/vnd.dece.mobile)%end;
%else %if &ext=uvp %then %do;%str(video/vnd.dece.pd)%end;
%else %if &ext=uvvp %then %do;%str(video/vnd.dece.pd)%end;
%else %if &ext=uvs %then %do;%str(video/vnd.dece.sd)%end;
%else %if &ext=uvvs %then %do;%str(video/vnd.dece.sd)%end;
%else %if &ext=uvv %then %do;%str(video/vnd.dece.video)%end;
%else %if &ext=uvvv %then %do;%str(video/vnd.dece.video)%end;
%else %if &ext=dvb %then %do;%str(video/vnd.dvb.file)%end;
%else %if &ext=fvt %then %do;%str(video/vnd.fvt)%end;
%else %if &ext=m4u %then %do;%str(video/vnd.mpegurl)%end;
%else %if &ext=mxu %then %do;%str(video/vnd.mpegurl)%end;
%else %if &ext=pyv %then %do;%str(video/vnd.ms-playready.media.pyv)%end;
%else %if &ext=uvu %then %do;%str(video/vnd.uvvu.mp4)%end;
%else %if &ext=uvvu %then %do;%str(video/vnd.uvvu.mp4)%end;
%else %if &ext=viv %then %do;%str(video/vnd.vivo)%end;
%else %if &ext=asf %then %do;%str(video/x-ms-asf)%end;
%else %if &ext=asx %then %do;%str(video/x-ms-asf)%end;
%else %if &ext=vob %then %do;%str(video/x-ms-vob)%end;
%else %if &ext=wm %then %do;%str(video/x-ms-wm)%end;
%else %if &ext=wmv %then %do;%str(video/x-ms-wmv)%end;
%else %if &ext=wmx %then %do;%str(video/x-ms-wmx)%end;
%else %if &ext=wvx %then %do;%str(video/x-ms-wvx)%end;
%else %if &ext=avi %then %do;%str(video/x-msvideo)%end;
%else %if &ext=movie %then %do;%str(video/x-sgi-movie)%end;
%else %if &ext=ice %then %do;%str(x-conference/x-cooltalk)%end;
%else %if "&ext"="in" %then %do;%str(text/plain)%end;
%else %do;
  %put %str(WARN)ING: extension &ext not found!;
  %put %str(WARN)ING- Returning text/plain.;
  %str(text/plain)
%end;

%mend mf_mimetype;