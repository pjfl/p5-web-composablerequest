package Web::ComposableRequest::Constants;

use strictures;
use parent 'Exporter::Tiny';

use Web::ComposableRequest::Exception;

our @EXPORT = qw( EXCEPTION_CLASS FALSE LANG NUL TRUE );

my $Exception_Class = 'Web::ComposableRequest::Exception';

sub FALSE () { 0    }
sub LANG  () { 'en' }
sub NUL   () { q()  }
sub TRUE  () { 1    }

sub EXCEPTION_CLASS () { __PACKAGE__->Exception_Class }

sub Exception_Class {
   my ($self, $class) = @_; defined $class or return $Exception_Class;

   $class->can( 'throw' ) or $Exception_Class->throw
      ( "Exception class ${class} is not loaded or has no throw method" );

   return $Exception_Class = $class;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Constants - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Constants;
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
