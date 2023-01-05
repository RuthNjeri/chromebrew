require 'package'

class Ca_certificates < Package
  description 'Common CA Certificates PEM files'
  homepage 'https://salsa.debian.org/debian/ca-certificates'
  version '20210119-2' # Do not replace version with @_ver, the install will break.
  @_ver = "#{version}[0..-3]"
  license 'MPL-1.1'
  compatibility 'all'
  source_url "https://salsa.debian.org/debian/ca-certificates/-/archive/debian/#{@_ver}/ca-certificates-debian-#{@_ver}.tar.bz2"
  source_sha256 'af30b4d9a2c58e42134067d29f0ba6120e5960fd140393d5574d4bdcf5b824d6'

  binary_url({
    aarch64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/ca_certificates/20210119-2_armv7l/ca_certificates-20210119-2-chromeos-armv7l.tar.xz',
     armv7l: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/ca_certificates/20210119-2_armv7l/ca_certificates-20210119-2-chromeos-armv7l.tar.xz',
       i686: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/ca_certificates/20210119-2_i686/ca_certificates-20210119-2-chromeos-i686.tar.xz',
     x86_64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/ca_certificates/20210119-2_x86_64/ca_certificates-20210119-2-chromeos-x86_64.tar.xz'
  })
  binary_sha256({
    aarch64: '84bb971e1d955d113b48013c694fd209f1627799f9c5a1e6123911c27d72ad4c',
     armv7l: '84bb971e1d955d113b48013c694fd209f1627799f9c5a1e6123911c27d72ad4c',
       i686: 'd8bdc641c52b7e551e2396f7276c09601b533211e1f43e21bffab55fba49eeab',
     x86_64: '4f3ef9802940646facd1408b34b378ef866829d1c60b3b23560465afff5b97c3'
  })

  no_patchelf

  def self.patch
    # Patch from:
    # https://gitweb.gentoo.org/repo/gentoo.git/plain/app-misc/ca-certificates/files/ca-certificates-20150426-root.patch
    @gentoo_patch = <<~GENTOO_CA_CERT_HEREDOC
               add a --root option so we can generate with DESTDIR installs
      #{'      '}
            --- a/image/usr/sbin/update-ca-certificates
            +++ b/image/usr/sbin/update-ca-certificates
            @@ -30,6 +30,8 @@ LOCALCERTSDIR=/usr/local/share/ca-certificates
             CERTBUNDLE=ca-certificates.crt
             ETCCERTSDIR=/etc/ssl/certs
             HOOKSDIR=/etc/ca-certificates/update.d
            +ROOT=""
            +RELPATH=""
      #{'       '}
             while [ $# -gt 0 ];
             do
            @@ -59,13 +61,25 @@ do
                 --hooksdir)
                   shift
                   HOOKSDIR="$1";;
            +    --root|-r)
            +      shift
            +      # Needed as c_rehash wants to read the files directly.
            +      # This gets us from $CERTSCONF to $CERTSDIR.
            +      RELPATH="../../.."
            +      ROOT=$(readlink -f "$1");;
                 --help|-h|*)
            -      echo "$0: [--verbose] [--fresh]"
            +      echo "$0: [--verbose] [--fresh] [--root <dir>]"
                   exit;;
               esac
               shift
             done
      #{'       '}
            +CERTSCONF="$ROOT$CERTSCONF"
            +CERTSDIR="$ROOT$CERTSDIR"
            +LOCALCERTSDIR="$ROOT$LOCALCERTSDIR"
            +ETCCERTSDIR="$ROOT$ETCCERTSDIR"
            +HOOKSDIR="$ROOT$HOOKSDIR"
            +
             if [ ! -s "$CERTSCONF" ]
             then
               fresh=1
            @@ -94,7 +107,7 @@ add() {
                                                               -e 's/,/_/g').pem"
               if ! test -e "$PEM" || [ "$(readlink "$PEM")" != "$CERT" ]
               then
            -    ln -sf "$CERT" "$PEM"
            +    ln -sf "${RELPATH}${CERT#{$ROOT}}" "$PEM"
                 echo "+$PEM" >> "$ADDED"
               fi
               # Add trailing newline to certificate, if it is missing (#635570)
    GENTOO_CA_CERT_HEREDOC
    File.write('ca-certificates-20150426-root.patch', @gentoo_patch)
    system 'patch -p 3 < ca-certificates-20150426-root.patch'

    system "sed -i 's,/usr/share/ca-certificates,#{CREW_PREFIX}/share/ca-certificates,g' \
      Makefile"
    system "sed -i 's,/usr/share/ca-certificates,#{CREW_PREFIX}/share/ca-certificates,g' \
      sbin/update-ca-certificates"
    system "sed -i 's,CERTSCONF=/etc/ca-certificates.conf,CERTSCONF=#{CREW_PREFIX}/etc/ca-certificates.conf,g' \
      sbin/update-ca-certificates"
    system "sed -i 's,ETCCERTSDIR=/etc/ssl/certs,ETCCERTSDIR=#{CREW_PREFIX}/etc/ssl/certs,g' \
      sbin/update-ca-certificates"
    system "sed -i 's,HOOKSDIR=/etc/ca-certificates/update.d,HOOKSDIR=#{CREW_PREFIX}/etc/ca-certificates/update.d,g' \
      sbin/update-ca-certificates"
    system "sed -i '/restorecon/d' sbin/update-ca-certificates"
    system "sed -i 's,/usr/sbin,#{CREW_PREFIX}/bin,g' sbin/Makefile"
  end

  def self.build
    system 'make'
  end

  def self.install
    FileUtils.mkdir_p("#{CREW_DEST_PREFIX}/etc/ssl/certs/")
    FileUtils.mkdir_p("#{CREW_DEST_PREFIX}/bin")
    FileUtils.mkdir_p("#{CREW_DEST_PREFIX}/share/ca-certificates/")
    system "make DESTDIR=#{CREW_DEST_DIR} install"
    @date_temp = `date -u`.chomp
    @ca_cert_conf = <<~CA_CERT_CONF_HEREDOC
      # Automatically generated by Chromebrew package #{Module.nesting.first}
      # from ca-certificates-debian-#{@_ver}
      # #{@date_temp}
      # Do not edit.
    CA_CERT_CONF_HEREDOC
    File.write("#{CREW_DEST_PREFIX}/etc/ca-certificates.conf", @ca_cert_conf)
    Dir.chdir "#{CREW_DEST_PREFIX}/share/ca-certificates" do
      system "find * -name '*.crt' | LC_ALL=C sort | sed '/examples/d' >> #{CREW_DEST_PREFIX}/etc/ca-certificates.conf"
    end
    system "sbin/update-ca-certificates --hooksdir '' --root #{CREW_DEST_DIR} --certsconf #{CREW_PREFIX}/etc/ca-certificates.conf"
    Dir.glob("#{CREW_DEST_PREFIX}/share/ca-certificates/mozilla/*.crt") do |cert_file|
      @cert_basename = File.basename(cert_file, '.crt')
      FileUtils.ln_sf "#{CREW_PREFIX}/share/ca-certificates/mozilla/#{@cert_basename}.crt",
                      "#{CREW_DEST_PREFIX}/etc/ssl/certs/#{@cert_basename}.pem"
    end
  end

  # This isn't run from install.sh, but that's ok. This is for cleanup if updated after an install.
  def self.postinstall
    # Do not call system update-ca-certificates as that tries to update certs in /etc .
    system "#{CREW_PREFIX}/bin/update-ca-certificates --fresh --certsconf #{CREW_PREFIX}/etc/ca-certificates.conf"
  end
end
