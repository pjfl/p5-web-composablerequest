package Web::ComposableRequest;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 4 $ =~ /\d+/gmx );

use Scalar::Util                      qw( blessed );
use Web::ComposableRequest::Base;
use Web::ComposableRequest::Constants qw( NUL );
use Web::ComposableRequest::Util      qw( deref is_hashref trim );
use Unexpected::Types                 qw( HashRef NonEmptySimpleStr
                                          Object Undef );
use Moo::Role ();
use Moo;

has 'config' => is => 'ro', isa => HashRef | Object | Undef, builder => sub {};

has 'request_class' => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   my $self  = shift;
   my $base  = __PACKAGE__.'::Base';
   my $conf  = $self->config or return $base;
   my $class = deref( $conf, 'request_class' ) // $base;
   my @roles = @{ deref( $conf, 'request_roles' ) // [] };

   @roles > 0 or return $class;

   @roles = map { (substr $_, 0, 1 eq '+')
                ?  substr $_, 1 : __PACKAGE__."::Role::${_}" } @roles;

   return Moo::Role->create_class_with_roles( $class, @roles );
};

sub new_from_simple_request {
   my ($self, $opts, @args) = @_; my $attr = { %{ $opts // {} } };

   $attr->{config} = $self->config if ($self->config);
   $attr->{env   } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params} = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args  } = (defined $args[ 0 ] && blessed $args[ 0 ])
                   ? [ $args[ 0 ] ] # Upload object
                   : [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   return $self->request_class->new( $attr );
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest;
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
