#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.firebrno.cz/modules/incidents/index.php');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Get items.
my @div = $root->find_by_attribute('id', 'menu')->find_by_attribute('class', 'article-content');
shift @div;
my @items = $div[0]->find_by_tag_name('p')->content_list;
my $shortcut;
my $desc;
foreach my $item (@items) {
	if (ref $item eq 'HTML::Element') {
		my $strong = $item->find_by_tag_name('strong');
		if ($strong) {
			$shortcut = $strong->as_text;
			remove_trailing(\$shortcut);
		}
	} else {
		my $desc = $item;
		remove_trailing(\$desc);
		$desc =~ s/^-\s*//ms;

		# Save.
		# TODO Update.
		print encode_utf8("- $shortcut: $desc\n");
		$dt->insert({
			'Shortcut' => $shortcut,
			'Description' => $desc,
		});
		# TODO Move to begin with create_table.
		$dt->create_index(['Shortcut'], 'data', 1, 1);

		# Clean.
		undef $shortcut;
		undef $desc;
	}
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
