package MusicBrainz::Server::Edit::Tracklist::Create;
use Carp;
use Moose;
use MooseX::Types::Moose qw( ArrayRef Str Int );
use MooseX::Types::Structured qw( Dict Optional );
use MusicBrainz::Server::Translation qw( l ln );
use MusicBrainz::Server::Constants qw( $EDIT_TRACKLIST_CREATE );
use MusicBrainz::Server::Data::Utils qw( artist_credit_to_ref );
use MusicBrainz::Server::Edit::Types qw( ArtistCreditDefinition Nullable NullableOnPreview );
use MusicBrainz::Server::Edit::Utils qw( load_artist_credit_definitions artist_credit_from_loaded_definition );
use MusicBrainz::Server::Track qw( unformat_track_length format_track_length );

extends 'MusicBrainz::Server::Edit::Generic::Create';
with 'MusicBrainz::Server::Edit::Role::Preview';

sub edit_type { $EDIT_TRACKLIST_CREATE }
sub edit_name { l("Add tracklist") }
sub _create_model { 'Tracklist' }
sub tracklist_id { shift->entity_id }

has '+data' => (
    isa => Dict[
        tracks => ArrayRef[
            Dict[
                name => Str,
                length => Nullable[Int],
                artist_credit => ArtistCreditDefinition,
                recording_id => NullableOnPreview[Int],
                position => Int,
            ]
        ]
    ]
);

sub foreign_keys
{
    my $self = shift;
    return {
        Artist => {
            map {
                load_artist_credit_definitions($_->{artist_credit})
            } @{ $self->data->{tracks} }
        }
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;

    return {
        tracks => [
            map { +{
                artist_credit => artist_credit_from_loaded_definition($loaded, $_->{artist_credit}),
                name          => $_->{name},
                length        => $_->{length},
                position      => $_->{position},
            } }
            sort { $a->{position} <=> $b->{position} }
                @{ $self->data->{tracks} }
        ]
    }
}

sub _insert_hash
{
    my ($self, $data) = @_;
    my @tracks = @{ $data->{tracks} };

    for my $track (@tracks) {
        $track->{artist_credit} = $self->c->model('ArtistCredit')->find_or_insert(@{ $track->{artist_credit} });
        if(!defined $track->{recording_id}) {
            my $rec_data = {
                artist_credit => $track->{artist_credit},
                name => $track->{name},
                length => $track->{length},
            };
            $track->{recording_id} = $self->c->model('Recording')->insert($rec_data)->id;
        }
    }

    return \@tracks;
}

sub _xml_arguments { ForceArray => [ 'artist_credit', 'tracks' ] }

__PACKAGE__->meta->make_immutable;
no Moose;
1;
