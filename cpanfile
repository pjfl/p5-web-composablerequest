requires "CGI::Simple" => "1.115";
requires "Class::Inspector" => "1.28";
requires "Exporter::Tiny" => "0.042";
requires "HTTP::Body" => "1.22";
requires "HTTP::Message" => "6.06";
requires "JSON::MaybeXS" => "1.003";
requires "Moo" => "2.000001";
requires "Role::Tiny" => "2.000001";
requires "Subclass::Of" => "0.003";
requires "Try::Tiny" => "0.22";
requires "URI" => "1.67";
requires "Unexpected" => "v0.39.0";
requires "namespace::autoclean" => "0.26";
requires "perl" => "5.010001";
requires "strictures" => "2.000000";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};

on 'test' => sub {
  requires "File::Spec" => "0";
  requires "IO::String" => "1.08";
  requires "Module::Build" => "0.4004";
  requires "Module::Metadata" => "0";
  requires "Sys::Hostname" => "0";
  requires "Test::Requires" => "0.06";
  requires "Unexpected" => "v0.39.0";
  requires "version" => "0.88";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
