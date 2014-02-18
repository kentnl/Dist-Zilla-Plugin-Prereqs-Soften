use strict;
use warnings;

package Dist::Zilla::Plugin::Prereqs::Soften;
$Dist::Zilla::Plugin::Prereqs::Soften::VERSION = '0.001000';
# ABSTRACT: Downgrade listed dependencies to recommendations if present.

use Moose;
use MooseX::Types::Moose qw( ArrayRef HashRef Str );
with 'Dist::Zilla::Role::PrereqSource';


















has 'modules' => (
  is => ro =>,
  isa => ArrayRef [Str],
  lazy    => 1,
  default => sub { [] },
);

has '_modules_hash' => (
  is      => ro                   =>,
  isa     => HashRef,
  lazy    => 1,
  builder => _build__modules_hash =>,
);
sub mvp_multivalue_args { return qw(modules) }
sub mvp_aliases { return { 'module' => 'modules' } }

sub _build__modules_hash {
  my $self = shift;
  return { map { ( $_, 1 ) } @{ $self->modules } };
}

sub _user_wants_softening_on {
  my ( $self, $module ) = @_;
  return exists $self->_modules_hash->{$module};
}
around dump_config => sub {
  my ( $orig, $self ) = @_;
  my $config = $self->$orig;
  my $this_config = { modules => $self->modules, };
  $config->{ q{} . __PACKAGE__ } = $this_config;
  return $config;
};

sub _soften_prereqs {
  my ( $self, $conf ) = @_;
  my $prereqs = $self->zilla->prereqs;

  my $source_reqs = $prereqs->requirements_for( $conf->{from_phase}, $conf->{from_relation} );
  my $target_reqs = $prereqs->requirements_for( $conf->{to_phase},   $conf->{to_relation} );

  for my $module ( $source_reqs->required_modules ) {
    next unless $self->_user_wants_softening_on($module);
    my $reqstring = $source_reqs->requirements_for_module($module);
    $target_reqs->add_string_requirement( $module, $reqstring );
    $source_reqs->clear_requirement($module);
  }
  return $self;
}

sub register_prereqs {
  my ($self) = @_;

  for my $phase (qw( build test runtime )) {
    for my $relation (qw( requires )) {
      $self->_soften_prereqs(
        {
          from_phase    => $phase,
          from_relation => $relation,
          to_phase      => $phase,
          to_relation   => 'recommends',

        }
      );
    }
  }
  return;
}









__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Prereqs::Soften - Downgrade listed dependencies to recommendations if present.

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

    [Prereqs::Soften]
    module = Foo
    module = Bar

This module iterates C<build>, C<require> and C<test> dependency lists
and migrates dependencies found in C<.requires> and demotes them to C<.recommends>

=head1 ATTRIBUTES

=head2 C<modules>

A C<multi-value> argument that specifies a module name to soften in C<prereqs>.

=for Pod::Coverage mvp_aliases
mvp_multivalue_args
register_prereqs

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
