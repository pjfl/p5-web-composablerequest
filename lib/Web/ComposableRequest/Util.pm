package Web::ComposableRequest::Util;

use strictures;
use parent 'Exporter::Tiny';

use Digest::MD5   qw( md5 );
use Encode        qw( decode );
use English       qw( -no_match_vars );
use List::Util    qw( first );
use Scalar::Util  qw( blessed );
use Sys::Hostname qw( hostname );
use URI::Escape   qw( );
use URI::http;
use URI::https;
use Web::ComposableRequest::Constants qw( EXCEPTION_CLASS LANG );

our @EXPORT_OK  = qw( base64_decode_ns base64_encode_ns bson64id bson64id_time
                      decode_array decode_hash deref extract_lang first_char
                      is_arrayref is_coderef is_hashref is_member new_uri
                      request_config_roles trim thread_id throw uri_escape );

my $bson_id_count  = 0;
my $bson_prev_time = 0;
my @config_roles   = ();
my $reserved       = q(;/?:@&=+$,[]);
my $mark           = q(-_.!~*'());                                   #'; emacs
my $unreserved     = "A-Za-z0-9\Q${mark}\E";
my $uric           = quotemeta( $reserved )."${unreserved}%\#";

# Private functions
my $_base64_char_set = sub {
   return [ 0 .. 9, 'A' .. 'Z', '_', 'a' .. 'z', '~', '+' ];
};

my $_bsonid_inc = sub {
   my $now = shift; $bson_id_count++;

   $now > $bson_prev_time and $bson_id_count = 0; $bson_prev_time = $now;

   return (pack 'n', thread_id() % 0xFFFF ).(pack 'n', $bson_id_count % 0xFFFF);
};

my $_bsonid_time = sub {
   my $now = shift;

   return (substr pack( 'N', $now >> 32 ), 2, 2).(pack 'N', $now % 0xFFFFFFFF);
};

my $_index64 = sub {
   return [ qw(XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX 64  XX XX XX XX
                0  1  2  3   4  5  6  7   8  9 XX XX  XX XX XX XX
               XX 10 11 12  13 14 15 16  17 18 19 20  21 22 23 24
               25 26 27 28  29 30 31 32  33 34 35 XX  XX XX XX 36
               XX 37 38 39  40 41 42 43  44 45 46 47  48 49 50 51
               52 53 54 55  56 57 58 59  60 61 62 XX  XX XX 63 XX

               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
               XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX) ];
};

my $_bsonid = sub {
   my $now  = time;
   my $host = substr md5( hostname ), 0, 3;
   my $pid  = pack 'n', $PID % 0xFFFF;

   return $_bsonid_time->( $now ).$host.$pid.$_bsonid_inc->( $now );
};

# Exported functions
sub base64_decode_ns ($) {
   my $x = shift; defined $x or return; my @x = split q(), $x;

   my $index = $_index64->(); my $j = 0; my $k = 0;

   my $len = length $x; my $pad = 64; my @y = ();

 ROUND: {
    while ($j < $len) {
       my @c = (); my $i = 0;

       while ($i < 4) {
          my $uc = $index->[ ord $x[ $j++ ] ];

          $uc ne 'XX' and $c[ $i++ ] = 0 + $uc; $j == $len or next;

          if ($i < 4) {
             $i < 2 and last ROUND; $i == 2 and $c[ 2 ] = $pad; $c[ 3 ] = $pad;
          }

          last;
       }

      ($c[ 0 ]   == $pad || $c[ 1 ] == $pad) and last;
       $y[ $k++ ] = ( $c[ 0 ] << 2) | (($c[ 1 ] & 0x30) >> 4);
       $c[ 2 ]   == $pad and last;
       $y[ $k++ ] = (($c[ 1 ] & 0x0F) << 4) | (($c[ 2 ] & 0x3C) >> 2);
       $c[ 3 ]   == $pad and last;
       $y[ $k++ ] = (($c[ 2 ] & 0x03) << 6) | $c[ 3 ];
    }
 }

   return join q(), map { chr $_ } @y;
}

sub base64_encode_ns (;$) {
   my $x = shift; defined $x or return; my @x = split q(), $x;

   my $basis = $_base64_char_set->(); my $len = length $x; my @y = ();

   for (my $i = 0, my $j = 0; $len > 0; $len -= 3, $i += 3) {
      my $c1 = ord $x[ $i ]; my $c2 = $len > 1 ? ord $x[ $i + 1 ] : 0;

      $y[ $j++ ] = $basis->[ $c1 >> 2 ];
      $y[ $j++ ] = $basis->[ (($c1 & 0x3) << 4) | (($c2 & 0xF0) >> 4) ];

      if ($len > 2) {
         my $c3 = ord $x[ $i + 2 ];

         $y[ $j++ ] = $basis->[ (($c2 & 0xF) << 2) | (($c3 & 0xC0) >> 6) ];
         $y[ $j++ ] = $basis->[ $c3 & 0x3F ];
      }
      elsif ($len == 2) {
         $y[ $j++ ] = $basis->[ ($c2 & 0xF) << 2 ];
         $y[ $j++ ] = $basis->[ 64 ];
      }
      else { # len == 1
         $y[ $j++ ] = $basis->[ 64 ];
         $y[ $j++ ] = $basis->[ 64 ];
      }
   }

   return join q(), @y;
}

sub bson64id (;$) {
   return base64_encode_ns( $_bsonid->() );
}

sub bson64id_time ($) {
   return unpack 'N', substr base64_decode_ns( $_[ 0 ] ), 2, 4;
}

sub decode_array ($$) {
   my ($enc, $param) = @_;

   (not defined $param->[ 0 ] or blessed $param->[ 0 ]) and return;

   for (my $i = 0, my $len = @{ $param }; $i < $len; $i++) {
      $param->[ $i ] = decode( $enc, $param->[ $i ] );
   }

   return;
}

sub decode_hash ($$) {
   my ($enc, $param) = @_;

   for my $k (keys %{ $param }) {
      if (is_arrayref( $param->{ $k } )) {
         $param->{ decode( $enc, $k ) }
            = [ map { decode( $enc, $_ ) } @{ $param->{ $k } } ];
      }
      else { $param->{ decode( $enc, $k ) } = decode( $enc, $param->{ $k } ) }
   }

   return;
}

sub deref (;$$) {
   my ($x, $k) = @_; $x and $k or return;

   blessed   ( $x ) and $x->can( $k )     and return $x->$k();
   is_hashref( $x ) and exists $x->{ $k } and return $x->{ $k };
   return;
}

sub extract_lang ($) {
   my $v = shift; return $v ? (split m{ _ }mx, $v)[ 0 ] : LANG;
}

sub first_char ($) {
   return substr $_[ 0 ], 0, 1;
}

sub is_arrayref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'ARRAY' ? 1 : 0;
}

sub is_coderef (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'CODE' ? 1 : 0;
}

sub is_hashref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? 1 : 0;
}

sub is_member (;@) {
   my ($candidate, @args) = @_; $candidate or return;

   is_arrayref $args[ 0 ] and @args = @{ $args[ 0 ] };

   return (first { $_ eq $candidate } @args) ? 1 : 0;
}

sub new_uri ($$) {
   return bless uric_escape( $_[ 0 ] ), 'URI::'.$_[ 1 ];
}

sub request_config_roles (;$) {
   my $role = shift; $role or return @config_roles;

   return push @config_roles, $role;
}

sub thread_id () {
   return exists $INC{ 'threads.pm' } ? threads->tid() : 0;
}

sub throw (;@) {
   EXCEPTION_CLASS->throw( @_ );
}

sub trim (;$$) {
   my $chs = $_[ 1 ] // " \t"; (my $v = $_[ 0 ] // q()) =~ s{ \A [$chs]+ }{}mx;

   chomp $v; $v =~ s{ [$chs]+ \z }{}mx; return $v;
}

sub uric_escape ($;$) {
   my ($v, $pattern) = @_; $pattern //= $uric;

   $v =~ s{([^$pattern])}{ URI::Escape::escape_char($1) }ego;
   utf8::downgrade( $v );
   return \$v;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Util - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Util;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Web-ComposableRequest.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
