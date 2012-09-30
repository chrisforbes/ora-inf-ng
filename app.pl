#!/usr/bin/env perl

use Mojolicious::Lite;
use Method::Signatures::Simple;
use MojoX::Redis;

my $redis = MojoX::Redis->new(server => '127.0.0.1:6379');

my $ttl = 300;		# server-side ttl is 5 minutes. client is expected
					# to ping again at about 60% of ttl.

get '/ping' => method () {
	my $ip = $self->tx->remote_address;
	my $port = $self->param('port') // 0;
	my $new = $self->param('new') // 0;
	my $yaml = $self->param('yaml') // '';

	$redis->incr('games') if $new;

	my $key = "$ip:$port";

	$redis->set($key => $yaml);
	$redis->expire($key => $ttl);
	$redis->sadd(active => $key);

	$self->render(text => 'It works!');
};

get '/games' => method () {
	$redis->get(games => func ($redis, $res) {
		$self->render(text => $res->[0]);
	});
};

get '/list' => method () {
	$redis->execute(eval => [q/
		local active_games = redis.call('smembers','active')
		local results = {}
		table.foreach(active_games, function(k,v)
			local z = redis.call('get',v)
			if z then
				table.insert(results, v)
				table.insert(results, redis.call('ttl',v))
				table.insert(results, z)
			end
		end)
		return results/, 0] => func($redis, $res) {
			my $text = '';
			my $id = 0;
			while (scalar @$res) {
				my $address = (shift @$res)->[0];
				my $ttl = (shift @$res)->[0];
				my $yaml = (shift @$res)->[0];

				$text .= "Game\@$id:\n\tAddress:$address\n\tTTL:$ttl\n\t";
				$text .= join("\n\t", split('\n',$yaml));

				++$id;
			}
			$self->render(text => $text);
	});
};

app->start;
