package JavaScript::Packer;

use warnings;
use strict;
use Carp;

use vars qw/$VERSION $COMMENT $DATA $WHITESPACE $CLEAN $BLOCK $WORD/;

# =========================================================================== #

$VERSION = '0.01';

$WORD = qr/([a-zA-Z0-9_]+)/;

$BLOCK = qr/(function\s*[a-zA-Z0-9_\x24]*\s*\(\s*(([a-zA-Z0-9_\x24][a-zA-Z0-9_\x24, ]*[a-zA-Z0-9_\x24])*)\s*\)\s*)?(\{([^{}]*)\})/;

$COMMENT = [
	{
		'regexp'	=> qr/(\/\/|;;;)[^\n]*\n?/,
		'replacement'	=> 'sprintf( " " )'
	},
	{
		'regexp'	=> qr/(\/\*[^*]*\*+([^\/][^*]*\*+)*\/)/,
		'replacement'	=> 'sprintf( " " )'
	}
];

$DATA = [
	{
		'regexp'	=> qr/('(\\.|[^'\\])*'|"(\\.|[^"\\])*")/,
		'replacement'	=> '$&'
	},
	{
		'regexp'	=> qr/\/\*@|@\*\/|\/\/@[^\n]*\n/,
		'replacement'	=> '$&'
	},
	{
		'regexp'	=> qr/\s+(\/(\\[\/\\]|[^*\/])(\\.|[^\/\n\\])*\/[gim]*)/,
		'replacement'	=> 'sprintf( "%s", $1 )'
	},
	{
		'regexp'	=> qr/([^a-zA-Z0-9_\x24\/'"*)\?:])(\/(\\[\/\\]|[^*\/])(\\.|[^\/\n\\])*\/[gim]*)/,
		'replacement'	=> 'sprintf( "%s%s", $1, $2 )'
	}
];

$WHITESPACE = [
	{
		'regexp'	=> qr/(\d)\s+(\.\s*[a-z\x24_\[(])/,
		'replacement'	=> 'sprintf( "%s %s", $1, $2 )'
	},
	{
		'regexp'	=> qr/([+-])\s+([+-])/,
		'replacement'	=> 'sprintf( "%s %s", $1, $2 )'
	},
	{
		'regexp'	=> qr/\b\s+(\x24)\s+\b/,
		'replacement'	=> 'sprintf( " %s ", $1 )'
	},
	{
		'regexp'	=> qr/(\x24)\s+\b/,
		'replacement'	=> 'sprintf( "%s ", $1 )'
	},
	{
		'regexp'	=> qr/\b\s+(\x24)/,
		'replacement'	=> 'sprintf( " %s", $1 )'
	},
	{
		'regexp'	=> qr/\b\s+\b/,
		'replacement'	=> 'sprintf( " " )'
	},
	{
		'regexp'	=> qr/\s+/,
		'replacement'	=> ''
	},
];

$CLEAN = [
	{
		'regexp'	=> qr/\(\s*;\s*;\s*\)/,
		'replacement'	=> '(;;)'
	},
	{
		'regexp'	=> qr/;+\s*([};])/,
		'replacement'	=> '$1'
	},
];

# =========================================================================== #

sub minify {
	my ( $scalarref, $opts ) = @_;
	
	if ( ref( $scalarref ) ne 'SCALAR' ) {
		carp( 'First argument must be a scalarref!' );
		return '';
	}
	
	return '' if ( ${$scalarref} eq '' );
	
	if ( ref( $opts ) ne 'HASH' ) {
		carp( 'Second argument must be a hashref of options! Using defaults!' ) if ( $opts );
		$opts = { 'compress' => 'minify', 'copyright' => '' };
	}
	else {
		$opts->{'compress'}	= grep( $opts->{'compress'}, ( 'minify', 'shrink', 'base62' ) ) ? $opts->{'compress'} : 'minify';
		$opts->{'copyright'}	= ( $opts->{'copyright'} and $opts->{'compress'} eq 'minify' ) ? ( '/* ' . $opts->{'copyright'} . ' */' ) : '';
	}
	
	my $data	= [];
	
	${$scalarref} =~ s/~jmv_\d+~/ /;
	${$scalarref} =~ s/~jmb_\d+~/ /;
	
	${$scalarref} =~ s/\\\r?\n//gsm;
	${$scalarref} =~ s/\r//gsm;
	
	my $_store = sub {
		my ( $regexp, $match, $data ) = @_;
		
		my @match = $match =~ /$regexp->{'regexp'}/;
		my $replacement = $regexp->{'replacement'};
		
		for ( my $i = 0; $i < scalar( @match ); $i++ ) {
			my $rep_char	= $i + 1;
			my $rep_match	= $match[$i] || '';
			
			$rep_match =~ s/[\/\\]/\\$&/g;
			
			$replacement =~ s/\$$rep_char/q\/$rep_match\//g;
		}
		
		$match =~ s/[\/\\]/\\$&/g;
		
		$replacement =~ s/\$&/q\/$match\//g;
		
		my $store = eval( $replacement . ';' );
		
		return '' unless ( $store );
		
		my $ret = '~jmv_' . scalar( @{$data} ) . '~';
		
		if ( $store =~ /^([^'"])(\/.*)$/sm ) {
			$ret = $1 . $ret;
			$store = $2;
		}
		
		push( @{$data}, $store );
		
		return $ret;
	};
	
	foreach my $regexp ( @$DATA ) {
		next unless ( $regexp->{'regexp'} );
		${$scalarref} =~ s/$regexp->{'regexp'}/&$_store( $regexp, $&, $data )/egsm;
	}
	
	foreach my $regexp ( @$COMMENT ) {
		next unless ( $regexp->{'regexp'} );
		${$scalarref} =~ s/$regexp->{'regexp'}/ /gsm;
	}
	
	foreach my $regexp ( @$WHITESPACE ) {
		next unless ( $regexp->{'regexp'} );
		${$scalarref} =~ s/$regexp->{'regexp'}/&$_store( $regexp, $&, $data )/egsm;
	}
	
	foreach my $regexp ( @$CLEAN ) {
		next unless ( $regexp->{'regexp'} );
		${$scalarref} =~ s/$regexp->{'regexp'}/&$_store( $regexp, $&, $data )/egsm;
	}
	
	while ( ${$scalarref} =~ /~jmv_(\d+)~/ ) {
		${$scalarref} =~ s/~jmv_(\d+)~/$data->[$1]/eg;
	}
	
	if ( $opts->{'compress'} eq 'shrink' or $opts->{'compress'} eq 'base62' ) {
		my $block	= [];
		$data		= [];
		
		foreach my $regexp ( @$DATA ) {
			next unless ( $regexp->{'regexp'} );
			${$scalarref} =~ s/$regexp->{'regexp'}/&$_store( $regexp, $&, $data )/egsm;
		}
		
		my $_decode = sub {
			my ( $match, $block ) = @_;
			
			while ( $match =~ /~jmb_\d+~/ ) {
				$match =~ s/~jmb_(\d+)~/$block->[$1]/eg;
			}
			
			return $match;
		};
		
		my $_encode = sub {
			my ( $match, $block ) = @_;
			
			my ( $func, undef, $args ) = $match =~ /$BLOCK/;
			
			if ( $func ) {
				$match = &$_decode( $match, $block );
				
				$args ||= '';
				
				my %block_vars = map { $_ => 1 } ( $match =~ /var\s+([a-zA-Z0-9_\x24]+)[^a-zA-Z0-9_\x24]/g ), split( /\s*,\s*/, $args );
				
				my $cnt = 0;
				foreach my $block_var ( keys( %block_vars ) ) {
					if ( length( $block_var ) > 1 ) {
						my $short_id = _encode52( $cnt );
						while ( $match =~ /[^a-zA-Z0-9_\x24\.]\Q$short_id\E[^a-zA-Z0-9_\x24:]/ ) {
							$short_id = _encode52( $cnt++ );
						}
							$match =~ s/([^a-zA-Z0-9_\x24\.])\Q$block_var\E([^a-zA-Z0-9_\x24:])/sprintf( "%s%s%s", $1, $short_id, $2 )/eg;
						$match =~ s/([^\{,a-zA-Z0-9_\x24\.])\Q$block_var\E:/sprintf( '%s%s:', $1, $short_id )/eg;
					}
				}
			}
			
			my $ret = '~jmb_' . scalar( @{$block} ) . '~';
			
			push( @{$block}, $match );
			
			return $ret;
		};
		
		while( ${$scalarref} =~ /$BLOCK/ ) {
			${$scalarref} =~ s/$BLOCK/&$_encode( $&, $block )/egsm;
		}
		
		${$scalarref} = &$_decode( ${$scalarref}, $block );
		
		while ( ${$scalarref} =~ /~jmv_(\d+)~/ ) {
			${$scalarref} =~ s/~jmv_(\d+)~/$data->[$1]/egsm;
		}
	}
	else {
		${$scalarref} = $opts->{'copyright'} . ${$scalarref} if ( $opts->{'copyright'} );
	}
	
	if ( $opts->{'compress'} eq 'base62' ) {
		my $words = {};
		
		my @words = ${$scalarref} =~ /$WORD/g;
		
		my $idx = 0;
		
		map {
			if ( exists( $words->{$_} ) ) {
				$words->{$_}->{'count'}++;
			}
			else {
				$words->{$_}->{'count'} = 1;
			}
		} @words;
		
		WORD: foreach my $word ( sort { $words->{$b}->{'count'} <=> $words->{$a}->{'count'} } keys( %{$words} ) ) {
			
			if ( exists( $words->{$word}->{'encoded'} ) and $words->{$word}->{'encoded'} eq $word ) {
				next WORD;
			}
			
			my $encoded = _encode62( $idx );
			
			if ( exists( $words->{$encoded} ) ) {
				my $next = 0;
				if ( exists( $words->{$encoded}->{'encoded'} ) ) {
					$words->{$word}->{'encoded'} = $words->{$encoded}->{'encoded'};
					$words->{$word}->{'index'} = $words->{$encoded}->{'index'};
					$next = 1;
				}
				$words->{$encoded}->{'encoded'} = $encoded;
				$words->{$encoded}->{'index'} = $idx;
				$idx++;
				next WORD if ( $next );
				redo WORD;
			}
			
			$words->{$word}->{'encoded'} = $encoded;
			$words->{$word}->{'index'} = $idx;
			
			$idx++;
		}
		
		${$scalarref} =~ s/$WORD/sprintf( "%s", $words->{$1}->{'encoded'} )/eg;
		
		${$scalarref} =~ s/([\\'])/\\$1/g;
		
		${$scalarref} =~ s/[\r\n]+/\\n/g;
		
		my $w_cnt = scalar( keys( %{$words} ) );
		
		my $pp = ${$scalarref};
		my $pa = $w_cnt > 2 ? $w_cnt < 62 ? $w_cnt : 62 : 2;
		my $pc = $w_cnt;
		my $pk = join( '|', map { $words->{$_}->{'encoded'} ne $_ ? $_ : '' } sort { $words->{$a}->{'index'} <=> $words->{$b}->{'index'} } keys( %{$words} ) );
		my $pe = 'String';
		my $pr = 'c';
		
		if ( $pa > 10 ) {
			if ( $pa <= 36 ) {
				$pe = q~function(c){return c.toString(a)}~;
			}
			$pr = q~e(c)~;
		}
		if ( $pa > 36 ) {
			$pe = q~function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))}~;
		}
		
		my $f_str = q~eval(function(p,a,c,k,e,r){e=%s;if(!''.replace(/^/,String)){while(c--)r[%s]=k[c]~;
		$f_str .= q~||%s;k=[function(e){return r[e]}];e=function(){return'\\\\w+'};c=1};while(c--)if(k[c])p=p.~;
		$f_str .= q~replace(new RegExp('\\\\b'+e(c)+'\\\\b','g'),k[c]);return p}('%s',%s,%s,'%s'.split('|'),0,{}))~;
		
		${$scalarref} = sprintf( $f_str, $pe, $pr, $pr, $pp, $pa, $pc, $pk );
	}
}

sub _encode52 {
	my $c = shift;
	
	my $m = $c % 52;
	
	my $ret = $m > 25 ? chr( $m + 39 ) : chr( $m + 97 );
	
	if ( $c >= 52 ) {
		$ret = _encode52( int( $c / 52 ) ) . $ret;
	}
	
	return $ret;
}

sub _encode62 {
	my $c = shift;
	
	my $m = $c % 62;
	
	my $ret = $m > 35 ? chr( $m + 29 ) : $m > 9 ? chr( $m + 87 ) : $m;
	
	if ( $c >= 62 ) {
		$ret = _encode62( int( $c / 62 ) ) . $ret;
	}
	
	return $ret;
}

1;

__END__

=head1 NAME

JavaScript::Packer - Perl version of Dean Edwards' Packer.js

=head1 VERSION

Version 0.01

=cut


=head1 SYNOPSIS

A JavaScript Compressor

This module does exactly the same as Dean Edwards' Packer.js

Take a look at http://dean.edwards.name/packer/

use JavaScript::Packer;

JavaScript::Packer::minify( $scalarref, $opts );

First argument must be a scalarref of JavaScript-Code.
Second argument must be a hashref of options. Possible options are

=over 4

=item compress

Defines compression level. Possible values are 'minify', 'shrink' and 'base62'.
Default value is 'minify'.

=item copyright

You can add a copyright notice on top of the script. The copyright notice will
only be added if the compression value is 'minify'.

=back

=head1 AUTHOR

Merten Falk, C<< <nevesenin at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-javascript-packer at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=JavaScript-Packer>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc JavaScript::Packer


=head1 COPYRIGHT & LICENSE

Copyright 2008 Merten Falk, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
