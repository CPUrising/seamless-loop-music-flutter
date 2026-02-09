use flutter_rust_bridge::frb;
use serde::Serialize;
use std::path::Path;
use lofty::config::{ParseOptions, ParsingMode};
use lofty::file::TaggedFileExt;
use lofty::probe::Probe;
use lofty::tag::Accessor;
use lofty::file::AudioFile;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::audio::{AudioBufferRef, Signal};
use symphonia::core::conv::IntoSample;
use std::fs::File;

#[derive(Debug, Serialize)]
#[frb(non_opaque)]
pub struct SimpleAudioInfo {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub sample_rate: Option<u32>,
    pub total_samples: Option<u64>,
    pub duration_ms: Option<u64>,
}

#[frb]
pub fn get_audio_info(path: String) -> Result<SimpleAudioInfo, String> {
    let path_ref = Path::new(&path);

    let tagged_file = Probe::open(path_ref)
        .map_err(|e| e.to_string())?
        .options(
            ParseOptions::new()
                .parsing_mode(ParsingMode::Relaxed)
                .read_tags(true)
                .read_properties(true),
        )
        .read()
        .map_err(|e| e.to_string())?;

    let props = tagged_file.properties();
    
    let mut title_str = None;
    let mut artist_str = None;
    if let Some(tag) = tagged_file.primary_tag().or_else(|| tagged_file.first_tag()) {
        title_str = tag.title().as_deref().map(|s| s.to_string());
        artist_str = tag.artist().as_deref().map(|s| s.to_string());
    }

    let sample_rate = props.sample_rate().unwrap_or(44100);
    let duration_secs = props.duration().as_secs_f64();
    let total_samples = (duration_secs * sample_rate as f64) as u64;

    Ok(SimpleAudioInfo {
        title: title_str,
        artist: artist_str,
        sample_rate: Some(sample_rate),
        total_samples: Some(total_samples),
        duration_ms: Some(props.duration().as_millis() as u64),
    })
}

#[frb]
pub fn read_audio_samples(
    path: String,
    start_sample: u64,
    count: u64,
) -> Result<Vec<f32>, String> {
    let file = File::open(path).map_err(|e| e.to_string())?;
    let mss = MediaSourceStream::new(Box::new(file), Default::default());

    let hint = Hint::new();

    let probed = symphonia::default::get_probe()
        .format(&hint, mss, &FormatOptions::default(), &MetadataOptions::default())
        .map_err(|e| e.to_string())?;

    let mut format = probed.format;

    let track = format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != symphonia::core::codecs::CODEC_TYPE_NULL)
        .ok_or_else(|| "No supported audio track found".to_string())?;

    let track_id = track.id;
    let codec_params = &track.codec_params;

    let mut decoder = symphonia::default::get_codecs()
        .make(codec_params, &Default::default())
        .map_err(|e| e.to_string())?;

    let mut samples = Vec::new();
    let mut current_sample_idx = 0u64;
    let end_sample = start_sample + count;
    
    loop {
        let packet = match format.next_packet() {
            Ok(packet) => packet,
            Err(symphonia::core::errors::Error::IoError(_)) => break,
            Err(e) => return Err(e.to_string()),
        };

        if packet.track_id() != track_id {
            continue;
        }

        let decoded = decoder.decode(&packet).map_err(|e| e.to_string())?;

        match decoded {
            AudioBufferRef::F32(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::U8(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::U16(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::U24(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::U32(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::S8(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::S16(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::S24(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::S32(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
            AudioBufferRef::F64(buf) => {
                process_buffer(&mut samples, &mut current_sample_idx, start_sample, end_sample, &buf);
            }
        }

        if current_sample_idx >= end_sample {
            break;
        }
    }

    Ok(samples)
}

fn process_buffer<S>(
    output: &mut Vec<f32>,
    current_idx: &mut u64,
    start: u64,
    end: u64,
    buf: &symphonia::core::audio::AudioBuffer<S>,
) where
    S: symphonia::core::sample::Sample + IntoSample<f32>,
{
    let planes = buf.planes();
    let num_channels = planes.planes().len();
    let num_frames = buf.frames();

    // Force output to be Stereo (2 channels)
    // Interleaved: L, R, L, R, ...
    for frame_idx in 0..num_frames {
        let global_idx = *current_idx;
        if global_idx >= start && global_idx < end {
            // Get Left channel sample
            let left_sample = if num_channels > 0 {
                planes.planes()[0][frame_idx].into_sample()
            } else {
                0.0
            };

            // Get Right channel sample (or duplicate Left if mono)
            let right_sample = if num_channels > 1 {
                planes.planes()[1][frame_idx].into_sample()
            } else {
                left_sample // Mono -> Stereo (duplicate)
            };

            output.push(left_sample);
            output.push(right_sample);
        }
        *current_idx += 1;
        if *current_idx >= end {
            break;
        }
    }
}
