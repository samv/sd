#!/usr/bin/env perl
package App::SD::CLI::Dispatcher;
use Prophet::CLI::Dispatcher -base;
use Moose;

on qr'^\?(.*)$' => sub {my $cmd = $1 || '';  redispatch('help'. $cmd,  @_); last_rule;};

# 'sd about' -> 'sd help about', 'sd copying' -> 'sd help copying'
on qr'^(about|copying)$' => sub { redispatch('help '.$1, @_); last_rule;};
on qr'^help (?:push|pull|publish|server)$' => sub { redispatch('help sync', @_); last_rule;};
on qr'^help (?:env)$' => sub { redispatch('help environment', @_); last_rule;};
on qr'^help (?:ticket)$' => sub { redispatch('help tickets', @_); last_rule;};
on qr'^help ticket (list|search|find)$' => sub { redispatch('help search', @_); last_rule;};
on qr'^help (?:list|find)$' => sub { redispatch('help search', @_); last_rule;};

on qr{ticket \s+ give \s+ (.*) \s+ (.*)}xi => sub {
    my $self = shift;
    $self->context->set_arg(type => 'ticket');
    $self->context->set_arg(id => $1);
    $self->context->set_arg(owner => $2);
    redispatch('update', $self, @_);
};

# allow type to be specified via primary commands, e.g.
# 'sd ticket display --id 14' -> 'sd display --type ticket --id 14'
on qr{^(ticket|comment|attachment) \s+ (.*)}xi => sub {
    my $self = shift;
    $self->context->set_arg(type => $1);
    redispatch($2, $self, @_);
};

#on qr'^about$' => sub { redispatch(('help about'); last_rule;};


# Run class based commands
on qr{.} => sub {
    my $self = shift;
    my $cli = $self->cli;

    my @possible_classes;

    # we want to dispatch on the original command "ticket attachment create"
    # AND on the command we received "create"
    for ([@{ $self->dispatching_on }], [split ' ', $_]) {
        my @pieces = __PACKAGE__->resolve_builtin_aliases(@$_);

        while (@pieces) {
            push @possible_classes, "App::SD::CLI::Command::" . join '::', @pieces;
            shift @pieces;
        }
    }

    for my $class (@possible_classes) {
        next unless Prophet::App->try_to_require($class);
        if (!$class->isa('App::SD::CLI::Command')) {
            warn "$class is not a subclass of App::SD::CLI::Command!";
            next;
        }

        return $class->run;
    }

    # found no class-based rule
    next_rule;
};

__PACKAGE__->dispatcher->add_rule(
    Path::Dispatcher::Rule::Dispatch->new(
        dispatcher => Prophet::CLI::Dispatcher->dispatcher,
    ),
);

my %CMD_MAP = (
    ls      => 'search',
    new     => 'create',
    edit    => 'update',
    rm      => 'delete',
    del     => 'delete',
    list    => 'search',
    display => 'show',
);

sub resolve_builtin_aliases {
    my $self = shift;
    my @cmds = @_;

    if (my $replacement = $CMD_MAP{ lc $cmds[-1] }) {
        $cmds[-1] = $replacement;
    }

    @cmds = map { ucfirst lc } @cmds;

    return wantarray ? @cmds : $cmds[-1];
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

