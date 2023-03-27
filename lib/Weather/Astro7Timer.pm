package Weather::Astro7Timer;

use 5.006;
use strict;
use warnings;

use Carp;

=head1 NAME

Weather::Astro7Timer - Simple client for the 7Timer.info Weather Forecast service

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.0_1';

=head1 SYNOPSIS

  my $w7t = Weather::Astro7Timer->new();

  # Get ASTRO weather for the Stonehenge area

  my %report = $w7t->get(
      product => 'astro',    # Forecast type (astro, civil, civillight, meteo, two)
      lat     => 51.2,       # Latitude
      lon     => -1.8,       # Longitude
  );

  # Dumping the result would give you:
  %report = {
      'product'    => 'astro',
      'init'       => '2023032606',
      'dataseries' => [{
              'temp2m'  => 6,
              'wind10m' => {
                  'speed'     => 2,
                  'direction' => 'NE'
              },
              'rh2m'         => 13,
              'seeing'       => 3,
              'timepoint'    => 3,
              'lifted_index' => 2,
              'prec_type'    => 'none',
              'cloudcover'   => 9,
              'transparency' => 6
          },
          {...},
          ...
      ]
  };

=head1 DESCRIPTION

Weather::Astro7Timer provides basic access to the L<7Timer.info|https://7Timer.info>
Weather Forecast API.
7Timer is a service based on NOAA's GFS and provides various types of forecast products.
It is mostly known for its ASTRO product intended for astronomers and stargazers, as
it provides an astronomical seeing and transparency forecast.

Pease see the L<official API documentation|https://www.7timer.info/doc.php> and
L<GitHub Wiki|https://github.com/Yeqzids/7timer-issues/wiki/Wiki> for details.

The module was made to serve the apps L<Xasteria|https://astro.ecuadors.net/xasteria/> and
L<Polar Scope Align|https://astro.ecuadors.net/polar-scope-align/>, but if your service
requires some extra functionality, feel free to contact the author about it.

=head1 CONSTRUCTOR

=head2 C<new>

    my $w7t = Weather::Astro7Timer->new(
        scheme  => $http_scheme?,
        timeout => $timeout_sec?,
        agent   => $user_agent_string?,
        ua      => $lwp_ua?,
    );
  
Optional parameters:

=over 4

=item * C<scheme> : You can specify C<http>. Default: C<https>.

=item * C<timeout> : Timeout for requests in secs. Default: C<30>.

=item * C<agent> : Customize the user agent string.

=item * C<ua> : Pass your own L<LWP::UserAgent> to customise further.

=back

=head1 METHODS

=head2 C<get>

    my $report = $w7t->get(
        product => $product,   # Forecast type (astro, civil, civillight, meteo, two)
        lat     => $lat,       # Latitude
        lon     => $lon,       # Longitude
        output  => $format?,   # Output format (default C<json>)
        unit    => $unit?,     # Units (default C<metric>)
        lang    => $language?, # Language (default C<en>)
        tzshift => $tz_shift?, # Timezone shift from UTC (hours, default C<0>)
        ac      => $alt_cor?,  # Altitude correction (default C<0>)
    );

    my %report = $w7t->get( ... );


Fetches a forecast report for the requested for the requested location.
Returns a string containing the JSON or XML data, except in array context, in which case,
as a convenience, it will use L<JSON> or L<XML::Simple> to decode it directly to a Perl hash.
For an explanation to the returned data, refer to the L<official API documentation|http://www.7timer.info/doc.php>.

If the request is not successful, it will C<die> throwing the C<< HTTP::Response->status_line >>.

Required parameters:

=over 4
 
=item * C<lat> : Latitude (-90 to 90). West is negative.

=item * C<lon> : Longitude (-180 to 180). South is negative.

=item * C<product> : Choose a forecast product from the available ones:

=over 4

=item * C<astro> : ASTRO 3-day forecast for astronomy/stargazing with 3h step (includes astronomical seeing, transparency).

=item * C<civil> : CIVIL 8-day forecast that provides a weather type enum (see docs for equivalent icons) with 3h step.

=item * C<civillight> : CIVIL Light simplified per-day forecast for next week.

=item * C<meteo> : A detailed meteorogical forecast including relative humidity and wind profile from 950hPa to 200hPa.

=item * C<two> : A Two Week Overview forecast.

=back

=back 


Optional parameters (see the API documentation for further details):

=over 4

=item * C<lang> : Supports C<zh-CN> or C<zh-TW>, otherwise default is C<en>.

=item * C<unit> : C<metric> (default) or C<british> units.

=item * C<output> : Output format, supports C<json> (default) or C<xml>, although
C<internal> will also work, returning png image.

=item * C<tzshift> : Timezone offset in hours ( -23 to 23).

=item * C<ac> : Altitude correction (e.g. temp) for high peaks. Default C<0>, accepts
C<2> or C<7> (in km). Only for C<astro> product.

=back

=head2 C<get_response>

    my $response = $w7t->get_response(
        lat     => $lat,
        lon     => $lon,
        product => $product
        %args?
    );

Same as C<get> except it returns the full L<HTTP::Response> from the API (so you
can handle bad requests yourself).


=head1 CONVENIENCE FUNCTIONS

=head2 C<products>

    my @products = Weather::Astro7Timer::products();

Returns the supported forecast products.

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless($self, $class);

    my %args = @_;

    $self->{ua}      = $args{ua};
    $self->{scheme}  = $args{scheme} || 'https';
    $self->{timeout} = $args{timeout} || 30;
    $self->{agent}   = $args{agent} || "libwww-perl Weather::Astro7Timer/$VERSION";

    return $self;
}

sub get {
    my $self = shift;
    my %args = @_;
    $args{lang}   ||= 'en';
    $args{output} ||= 'json';

    my $resp = $self->get_response(%args);

    if ($resp->is_success) {
        return _output($resp->decoded_content, wantarray ? $args{output} : '');
    }
    else {
        die $resp->status_line;
    }
}

sub get_response {
    my $self = shift;
    my %args = @_;

    croak("product was not defined")
        unless $args{product};

    croak("product not supported")
        unless grep { /^$args{product}$/ } products();

    croak("lat between -90 and 90 expected")
        unless defined $args{lat} && abs($args{lat}) <= 90;

    croak("lon between -180 and 180 expected")
        unless defined $args{lon} && abs($args{lon}) <= 180;

    my $url = $self->_weather_url(%args);

    unless ($self->{ua}) {
        require LWP::UserAgent;
        $self->{ua} = LWP::UserAgent->new();
    }

    $self->{ua}->agent($self->{agent});    
    $self->{ua}->timeout($self->{timeout});

    return $self->{ua}->get($url);
}

sub _weather_url {
    my $self = shift;
    my %args = @_;
    my $prod = delete $args{product};
    my $url =
          $self->{scheme}
        . "://www.7timer.info/bin/$prod.php?"
        . join("&", map {"$_=$args{$_}"} keys %args);

    return $url;
}

sub _output {
    my $str    = shift;
    my $format = shift;

    return $str unless $format;

    if ($format eq 'json') {
        require JSON;
        return %{JSON::decode_json($str)};
    } elsif ($format eq 'xml') {
        require XML::Simple;
        return %{XML::Simple::XMLin($str)};
    }
    return (data => $str);
}

sub products {
    return qw/astro two civil civillight meteo/;
}

=head1 AUTHOR

Dimitrios Kechagias, C<< <dkechag at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests either on L<GitHub|https://github.com/dkechag/Weather-Astro7Timer> (preferred), or on RT (via the email
C<bug-weather-astro7timer at rt.cpan.org> or L<web interface|https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Weather-Astro7TImer>).

I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 GIT

L<https://github.com/dkechag/Weather-Astro7Timer>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2023 by Dimitrios Kechagias.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

1;
