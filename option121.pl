#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(ceil);
use Data::Dumper;

use utf8;
binmode STDOUT, ':encoding(utf8)';

# 機種選択
my $model = 'CISCO';

my %sep = (
	'IX' => '',
	'YAMAHA' => ',',
	'CISCO' => ':',
);
my $separator = $sep{$model};
my $route = '';
my ($network, $mask, $gateway);

print "enter Distination net/mask and Gateway <NET>/<bit> <GW>\n";
print "Default route --> 0/0 <gateway>\n";
while (<DATA>){
	print "(ex: 10.20.30.40/16 172.31.23.5) ==> ";
	$network = $_; 
	chomp $network;
	last
		if $network eq 'q' or $network eq '';

	die "\n\n--->>> invalid input <<<--- : $network\n\n"
		if (($network, $gateway) = split " ", $network) !=2 ;
	die "\n\n--->>> invalid Distination net/mask <<<--- : $network\n\n"
		if (($network, $mask)    = split qw(/), $network) != 2;

	$route = $route . $separator . &destNet ($network,$mask);
	$route = $route . $separator . &destGW ($gateway);

	print "\nNext or quit (q)\n";
}

$route =~ s/^$separator//;
if    ($model =~ /ix/i)		{ printf "\n\noption 249 hex %s\n", $route }
elsif ($model =~ /yamaha/i)	{ printf "\n\ndhcp scope option 1 249=%s\n", $route }
elsif ($model =~ /cisco/i)	{ printf "\n\noption 121 hex %s\n", $route }


# $_[0] : IP addr
# $_[1] : IP mask bits
sub destNet () {
	# default route?
	return "00" if $_[1] eq "0";

	die "\n\n--->>> invalid Distination net addr <<<--- : $_[0]\n\n"
		if ($_[0] !~ /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/);
	die "\n\n--->>> invalid Distination net mask <<<--- : $_[1]\n\n"
		if ($_[1] !~ /^[0-2]?[0-9]|3[0-2]$/);

	my $mask_octets = ceil($_[1] / 8);
	my $mask_dec = oct(sprintf "0b%s", "1"x$_[1] . "0"x(32-$_[1]));

	my @IP = split /\./, $_[0];

	my $IP_dec = hex (sprintf "%02x%02x%02x%02x", $IP[0],$IP[1],$IP[2],$IP[3]);
	my $IP_hex = sprintf "%08x", $IP_dec & $mask_dec;
	@IP = ($IP_hex =~ /.{2}/g)[0..$mask_octets - 1];

	# hex : mask,IP1,IP2,IP3,IP4
	return join $separator, (sprintf ('%02x',$_[1]), @IP);
}

sub destGW () {
	my @IP;
	die "\n\n--->>> invalid Gateway addr <<<--- : $_[0]\n\n"
		if (@IP = split /\./,$_[0]) != 4;
	# hex : IP1,IP2,IP3,IP4
	return join $separator, (map {sprintf '%02x',$_} @IP);
}

# 以下、データ
__END__
10.0.0.0/8    192.168.10.200
172.16.0.0/12 192.168.10.200
0/0           192.168.10.250
q

# 記事
#	https://qiita.com/jp_yen/items/bef91748a31aecb60d79
# 参考
#	http://blog.grandaria.com/?p=234
#	https://qiita.com/kyokuheki/items/ccf770c6475a236d2035
#	http://www.xrx.ca/hexroute.htm
# 
# DHCP 設定例
#
# リース範囲
#	192.168.10.100-192.168.10.150
#	192.168.10.111～192.168.10.119 を除外
# ネットワーク/マスク
#	192.168.10.0/24
# デフォルトゲートウェイ
#	192.168.10.250
# DNS
# 	1.1.1.1, 1.0.0.1
# ドメイン名
#   my.home
# リース期間
# 	1時間 10分
# 追加のルート
#   10.0.0.0/8    GW 192.168.10.200
#   172.16.0.0/12 GW 192.168.10.200
#
# NEC IX
# ip dhcp enable
# ip dhcp profile Pool-192.168.10
# assignable-range 192.168.10.100 192.168.10.150
# subnet-mask 255.255.255.0
# default-gateway 192.168.10.250
# dns-server 1.1.1.1 1.0.0.1
# domain-name my.home
# lease-time 4200
# option 249 hex 080ac0a80ac80cac10c0a80ac8
#
# ip dhcp excluded-address 192.168.10.111 192.168.10.119
#
# show ip dhcp server
# show ip dhcp profile Pool-192.168.10
# show ip dhcp-client binding
# show ip dhcp-client statistics
# show ip dhcp-client summary
# show ip dhcp lease [detail]
#
# YAMAHA
# dhcp service server
# dhcp server rfc2131 compliant on ; RFC1541 ではなく RFC2131 にする
# dhcp duplicate check 300 500	; 直接接続と、relay 時のタイムアウト ms
# dhcp scope 1 192.168.10.100-192.168.10.150/24 except 192.168.10.111 gateway 192.168.10.250 expire 1:10
# dns server 1.1.1.1 203.133.238.132
# dhcp scope option 1 121=08,0a,c0,a8,0a,c8,0c,ac,10,c0,a8,0a,c8
# dhcp scope option 1 249=08,0a,c0,a8,0a,c8,0c,ac,10,c0,a8,0a,c8
#
# show status dhcp [summary] [scope_n]
#
# CISCO
# service dhcp
# ip dhcp ping timeout 300
# ip dhcp pool Pool-192.168.10
#  network 192.168.10.0 /24
#  class Class-192-168-10
#  address range 192.168.10.100 192.168.10.150
#  default-router 192.168.10.250
#  dns-server 1.1.1.1 1.0.0.1
#  domain-name my.home
#  lease 0 1 10 
#  option 121 hex 08:0a:c0:a8:0a:c8:0c:ac:10:c0:a8:0a:c8
# ip dhcp excluded-address 192.168.10.111 192.168.10.199
#
## ip dhcp excluded-address 192.168.10.0 192.168.10.99
## ip dhcp excluded-address 192.168.10.151 192.168.10.255
#
# show ip dhcp pool [name]
# show ip dhcp binding [address]
# show ip dhcp conflict [address]
# show ip dhcp server statistics [type number]

