package Web::ComposableRequest::Session;

use namespace::autoclean;

use Web::ComposableRequest::Constants qw( FALSE NUL TRUE );
use Web::ComposableRequest::Util      qw( bson64id );
use Unexpected::Types                 qw( Bool CodeRef HashRef NonEmptySimpleStr
                                          NonZeroPositiveInt Object SimpleStr
                                          Undef );
use Moo;

# Public attributes
has 'authenticated' => is => 'rw',  isa => Bool, default => FALSE;

has 'messages'      => is => 'ro',  isa => HashRef, builder => sub { {} };

has 'updated'       => is => 'ro',  isa => NonZeroPositiveInt, required => TRUE;

has 'username'      => is => 'rw',  isa => SimpleStr, default => NUL;

# Private attributes
has '_config'       => is => 'ro',  isa => Object, init_arg => 'config',
   required         => TRUE;

has '_log'          => is => 'ro',  isa => CodeRef, init_arg => 'log',
   required         => TRUE;

has '_mid'          => is => 'rwp', isa => NonEmptySimpleStr | Undef;

has '_session'      => is => 'ro',  isa => HashRef, init_arg => 'session',
   required         => TRUE;

# Private methods
my $_session_attr = sub {
   my $config = shift; my @attrs = qw( authenticated messages username );

   return sort keys %{ $config->session_attr }, @attrs;
};

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   for my $k ($_session_attr->( $attr->{config} )) {
      my $v = $attr->{session}->{ $k }; defined $v and $attr->{ $k } = $v;
   }

   $attr->{updated} //= time;

   return $attr;
};

sub BUILD {
   my $self = shift; my $max_time = $self->_config->max_sess_time;

   if ($self->authenticated and $max_time
       and time > $self->updated + $max_time) {
      my $username = $self->username; $self->authenticated( FALSE );
      my $message  = 'User [_1] session expired';

      $self->_set__mid( $self->status_message( [ $message, $username ] ) );
   }

   return;
}

# Public methods
sub clear_status_message {
   my ($self, $req) = @_; my ($mid, $msg);

   $mid = $req->query_params->( 'mid', { optional => TRUE } )
      and $msg = delete $self->messages->{ $mid }
      and return $req->loc( @{ $msg } );

   $mid = $self->_mid
      and $msg = delete $self->messages->{ $mid }
      and $self->_log->( { level   => 'debug',
                           message => $req->loc_default( @{ $msg } ) } );

   return $msg ? $req->loc( @{ $msg } ) : NUL;
}

sub status_message {
   my $mid = bson64id; $_[ 0 ]->messages->{ $mid } = $_[ 1 ]; return $mid;
}

sub update {
   my $self = shift; my @messages = sort keys %{ $self->messages };

   while (@messages > $self->_config->max_messages) {
      my $mid = shift @messages; delete $self->messages->{ $mid };
   }

   for my $k ($_session_attr->( $self->_config )) {
      $self->_session->{ $k } = $self->$k();
   }

   $self->_session->{updated} = time;
   return;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Session - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Session;
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
