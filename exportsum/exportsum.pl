#! /usr/bin/perl

BEGIN {
  eval { require Compress::Zlib };
  if ($@) {
    eval { require String::CRC32 };
    if ($@) {
      print STDERR "No crc32() implementation available!\nInstall Compress::Zlib or String::CRC32 and try again.\n";
      exit 1;
    } else {
      import String::CRC32 qw(crc32);
    }
  } else {
    import Compress::Zlib qw(crc32);
  }
}

use strict;
use warnings;

my $type = 0; # 0: none, 1: text, 2: bin, 3: variables
my ($crc, $expected, $last);

binmode STDIN;
$/ = "\012";

open(EXPORT, $ARGV[0]) or die "$!";
while(defined($_ = <EXPORT>)) {
  s/\015?\012$/\n/;
  if ($type == 0) {
reinterprete:
    my $file;
    if (/^\*\*\*\* CFGFILE:(\S+)/) {
      $file = $1;
      $type = 1;
      print $_;
    } elsif (/^\*\*\*\* BINFILE:(\S+)/) {
      $file = $1;
      $type = 2;
      print $_;
    } elsif (/^\*\*\*\* (.+) CONFIGURATION EXPORT/) {
      $type =3;
      print $_;
    } elsif (/^\*\*\*\* END OF EXPORT (\S+)/) {
      $expected = hex($1);
      last;
    }
    if (defined $file) {
      $crc = crc32($file."\x0", $crc);
      undef $file;
    }
  } elsif ($type == 1) {
    if (/^\*\*\*\* END OF FILE/) {
      $type = 0;
      if (defined $last) {
        # remove last LF
        chop $last;
	$crc = crc32($last, $crc);
        undef $last;
      }
    } else {
      if (defined $last) {
        $crc = crc32($last, $crc);
      }
      $last = $_;
    }
  } elsif ($type == 2) {
    if (/^\*\*\*\* END OF FILE/) {
      $type = 0;
    } else {
      chop;
      $crc = crc32(pack("H*", $_), $crc);
    }
  } elsif ($type == 3) {
    # implicit end of section
    if (/^\*\*\*\*/) {
      $type = 0;
      goto reinterprete;
    }
    chop;
    if (/^([^=]+)=(.*)$/) {
      $crc = crc32($1.$2."\x0", $crc);
    }
  }
}

if ($crc != $expected) {
  printf "WRONG CHECKSUM %08x vs. %08x\n", $crc, $expected;
} else {
  print "CHECKSUM OK\n";
}
