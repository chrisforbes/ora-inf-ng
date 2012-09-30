#!/usr/bin/env perl

use Mojolicious::Lite;
use Method::Signatures::Simple;
use MojoX::Redis;

my $redis = MojoX::Redis->new(server => '127.0.0.1:6379');

my $ttl = 300;		# server-side ttl is 5 minutes. client is expected
					# to ping again at about 60% of ttl.

get '/ping' => method () {
	my $ip = $self->tx->remote_address;
	my $port = $self->param(port => 0);
	my $new = $self->param(new => 0);
	my $yaml = $self->param(yaml => '');

	$redis->incr('games') if $new;

	my $key = "$ip:$port";

	$redis->set($key => $yaml);
	$redis->expire($key => TTL());

	$self->render(text => 'It works!');
};

get '/games' => method () {
	$redis->get('games' => func ($redis, $res) {
			$self->render('text' => $res->[0]);
		});
};

app->start;
