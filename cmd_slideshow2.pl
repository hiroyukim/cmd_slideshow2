use strict;
use warnings;
use utf8;
use Cwd;
use File::HomeDir;
use Text::Xatena;
use Path::Class;
use File::Copy::Recursive qw(dircopy);
use Text::Xatena::Util;
use Params::Validate qw/:all/;
use Text::Xslate;

my $CMD_SLIDESHOW_DIR = dir( File::HomeDir->my_home, ".cmd_slideshow2")->stringify;
my $JS_DIR            = dir($CMD_SLIDESHOW_DIR, "js"); 
my $OUTPUT_DIR        = dir( cwd(),'slideshow')->stringify;
my $THX               = Text::Xatena->new( hatena_compatible => 1 );
my $TX                = Text::Xslate->new( syntax => 'TTerse', path => [$CMD_SLIDESHOW_DIR]);
my $TITLE_TEMPLATE    = 'title_template.html';
my $TEMPLATE          = 'template.html';
my $TOTAL             = 0;

{    
    no strict 'refs';
    no warnings 'redefine';
    local *{"Text::Xatena::Node::SuperPre\::as_html"} = sub {
        my ($self, %opts) = @_;
        sprintf('<pre class="prettyprint">%s</pre>',
            escape_html(join "", @{ $self->children })
        );
    };
}

sub main {
    my ($path) = validate_pos(@_,
        { type => SCALAR },
    );

    unless( -e $OUTPUT_DIR ) {
        mkdir $OUTPUT_DIR;
        local $File::Copy::Recursive::CopyLink = 0;
        dircopy($JS_DIR,dir($OUTPUT_DIR,"js"));
    }

    my $header = header($path);
    my $body   = body($path);
    $TOTAL     = @{$body};

    render(0,$header,'');

    my $id = 1;
    for my $row ( @{$body} ) {
        render($id++, $header,parser(join '', @{$row} ) );
    }
}

sub render {
    my ($id,$header,$body) = validate_pos(@_,
        { type => SCALAR   },
        { type => HASHREF  },
        { type => SCALAR   },
    ); 

    open my $fh, '>:utf8', "$OUTPUT_DIR/$id.html";
    my $string = $TX->render(
        ( $id == 0 ) ? $TITLE_TEMPLATE : $TEMPLATE,
        {
            total  => $TOTAL,
            page   => $id,
            text   => $body,
            header => $header,
            title  => $header->{title},
            author => $header->{author},
        }
    );
    print $fh $string;
    close $fh;
};

sub body {
    my $path = shift;

    my $pre_fg;
    my $sections = 0;
    my @body;
    iterator($path => sub {
        my $line = shift;

        if( $line =~ /^>\|.*\|$/ ) {
            $pre_fg = 1;
        }
        elsif( $line =~ /^\|.*\|<$/ ) {
            $pre_fg = 0;
        }

        if( !$pre_fg && $line =~ /^\*([^\*]+)$/ ) {
            push @{$body[$sections++]},$line;      
        }
        elsif( defined $sections && @body ) {
            push @{$body[$sections-1]},$line;      
        }

    });

    return [@body];
}

sub header {
    my $path = shift;

    my %header;
    iterator($path => sub {
        my $line = shift;
        chomp $line;

        if( $line =~ /^\s*(title|author)\s*:\s*(.+)$/) {
            $header{$1} = $2;
        }

        return if $line =~ /^__BODY__$/ ; 
    });

    return \%header; 
}

sub iterator {
    my ($path,$code) = @_;

    open my $fh, '<:utf8' , $path or $!;

    while( my $line = <$fh> ) {
        $code->($line);
    }

    close($fh);
}

sub parser {
    my $text = shift;
    

    return $THX->format($text);
}

main(@ARGV) && exit();

__END__

Useage:

    cmd_slideshow2.pl source.txt