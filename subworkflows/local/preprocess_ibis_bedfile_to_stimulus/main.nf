/**
 * Preprocess IBIS BED file to STIMULUS format
 *
 * This subworkflow is designed to process a BED file and convert it into STIMULUS format,
 * preparing datasets for downstream sequence-based classification tasks.
 *
 * Workflow Steps:
 *   1. Center peaks and trim them to a fixed size.
 *   2. Extract foreground (target).
 *   3. Extract background (aliens, shades, random).
 *   4. Convert the processed peaks into FASTA format.
 *   5. Convert the extracted sequences into a stimulus input CSV format.
 *
 * Expected Inputs:
 *   - A channel containing BED file with peak regions.
 *   - A configuration channel providing the necessary details for extracting target
 *     (foreground) and background.
 *   - A channel containing the genome FASTA file.
 *   - A channel containing the genome sizes file.
 *
 * Output:
 *   - A STIMULUS formatted file containing sequences for both the target (foreground) and
 *     the corresponding background regions.
 *
 * TODO:
 *   - A meta.yaml file describing the workflow configuration, metadata, and dependencies
 *     should be created as part of the workflow documentation.
 */

include { GAWK as CENTER_AROUND_PEAK                        } from '../../../modules/nf-core/gawk'
include { AWK_EXTRACT as EXTRACT_FOREGROUND                 } from '../../../modules/local/awk/extract'
include { AWK_EXTRACT as EXTRACT_BACKGROUND_ALIENS          } from '../../../modules/local/awk/extract'
include { BEDTOOLS_SHIFT as EXTRACT_BACKGROUND_SHADE        } from '../../../modules/nf-core/bedtools/shift'
include { BEDTOOLS_SHUFFLE as EXTRACT_BACKGROUND_SHUFFLE    } from '../../../modules/local/bedtools/shuffle'
include { BEDTOOLS_SUBTRACT                                 } from '../../../modules/nf-core/bedtools/subtract'
include { BEDTOOLS_GETFASTA as BEDTOOLS_GETFASTA_FOREGROUND } from '../../../modules/nf-core/bedtools/getfasta'
include { BEDTOOLS_GETFASTA as BEDTOOLS_GETFASTA_BACKGROUND } from '../../../modules/nf-core/bedtools/getfasta'
include { GAWK as BACKGROUND_FOREGROUND_TO_STIMULUS_CSV     } from '../../../modules/nf-core/gawk'


workflow PREPROCESS_IBIS_BEDFILE_TO_STIMULUS {
    take:
    ch_input
    ch_config
    ch_genome
    ch_genome_sizes

    main:

    // TODO: it would be nice to check that the input file is actually a bed file
    ch_versions = Channel.empty()

    // ==============================================================================
    // align peaks
    // ==============================================================================

    // use the GAWK nf-core module for modifying bed start and end values
    // based on distance from peak (centering).

    ch_input_for_centering = ch_input
        .combine(ch_genome_sizes.map{it[1]})
        .map { meta, input, genome_sizes ->
            [meta, [genome_sizes, input]]
        }
    ch_awk_program = Channel.fromPath('./bin/center_around_peak.sh')

    CENTER_AROUND_PEAK(
        ch_input_for_centering,
        ch_awk_program
    )
    ch_input = CENTER_AROUND_PEAK.out.output
    ch_versions = ch_versions.mix(CENTER_AROUND_PEAK.out.versions)

    // ==============================================================================
    // extract foreground
    // ==============================================================================

    // prepare the input to extract foreground
    // Note that same target can be present in multiple configurations of different
    // background definitions. Hence, here we extract only the relevant information
    // for foreground and apply unique()
    ch_foreground_ids = ch_config
        .map{ it ->
            [[id: it.target, variable: it.variable, target: it.target], it.variable, it.target]
        }
        .unique()

    EXTRACT_FOREGROUND(
        ch_foreground_ids,
        ch_input.collect()
    )
    ch_foreground = EXTRACT_FOREGROUND.out.extracted_data
    ch_versions = ch_versions.mix(EXTRACT_FOREGROUND.out.versions)

    // ==============================================================================
    // extract background
    // ==============================================================================

    // extract background - aliens

    ch_background_for_aliens = ch_config
        .filter { it.background_type == 'aliens' }
        .map{ it ->
            [it, it.variable, it.background]
        }

    EXTRACT_BACKGROUND_ALIENS(
        ch_background_for_aliens,
        ch_input.collect()
    )
    ch_background_aliens = EXTRACT_BACKGROUND_ALIENS.out.extracted_data
    ch_versions = ch_versions.mix(EXTRACT_BACKGROUND_ALIENS.out.versions)

    // create input channel for shade and shuffle
    // as they use the same input structure

    ch_background_to_extract = ch_config
        .combine( ch_foreground )
        .map { meta, meta_input, input ->
            if ((meta.variable == meta_input.variable) &&
                (meta.target == meta_input.target)) {
                return [meta, input]
            }
        }
        .branch {
            shade: it[0].background_type == 'shade'
            shuffle: it[0].background_type == 'shuffle'
        }

    // extract background - shades
    // this option creates a background with peaks located at a nearby region from
    // the foreground peaks

    EXTRACT_BACKGROUND_SHADE(
        ch_background_to_extract.shade,
        ch_genome_sizes.collect()
    )
    ch_background_shade = EXTRACT_BACKGROUND_SHADE.out.bed
    ch_versions = ch_versions.mix(EXTRACT_BACKGROUND_SHADE.out.versions)

    // extract background - shuffle
    // this option creates a background with randomly shuffled peaks

    EXTRACT_BACKGROUND_SHUFFLE(
        ch_background_to_extract.shuffle,
        ch_genome_sizes.collect()
    )
    ch_background_shuffle = EXTRACT_BACKGROUND_SHUFFLE.out.bed
    ch_versions = ch_versions.mix(EXTRACT_BACKGROUND_SHUFFLE.out.versions)

    // merge different background if needed
    // TODO: implement this
    // for the moment just mix everything

    ch_background = ch_background_aliens
        .mix(ch_background_shade)
        .mix(ch_background_shuffle)

    // run bedtools to remove overlapping peaks
    // this creates a clean background with no overlapping peaks with the foreground

    ch_background_with_foreground = ch_background
        .combine(ch_foreground)
        .map{ meta_bg, bg, meta_fg, fg ->
            if ((meta_bg.variable == meta_fg.variable) &&
                (meta_bg.target == meta_fg.target)) {
                return [meta_bg, bg, fg]
            }
        }

    BEDTOOLS_SUBTRACT(ch_background_with_foreground)
    ch_background = BEDTOOLS_SUBTRACT.out.bed
    ch_versions = ch_versions.mix(BEDTOOLS_SUBTRACT.out.versions)

    // ==============================================================================
    // extract fasta sequences
    // ==============================================================================

    // run bedtools to convert to fasta

    BEDTOOLS_GETFASTA_FOREGROUND(
        ch_foreground,
        ch_genome.map{it[1]}.collect()
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GETFASTA_FOREGROUND.out.versions)

    BEDTOOLS_GETFASTA_BACKGROUND(
        ch_background,
        ch_genome.map{it[1]}.collect()
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GETFASTA_BACKGROUND.out.versions)

    ch_foreground = BEDTOOLS_GETFASTA_FOREGROUND.out.fasta
    ch_background = BEDTOOLS_GETFASTA_BACKGROUND.out.fasta

    // ==============================================================================
    // convert to stimulus input csv format
    // ==============================================================================

    ch_input_for_formatting = ch_background
        .combine(ch_foreground)
        .map{ meta_bg, bg, meta_fg, fg ->
            if ((meta_bg.variable == meta_fg.variable) &&
                (meta_bg.target == meta_fg.target)) {
                return [meta_bg, [bg, fg]]
            }
        }
    ch_awk_program = Channel.fromPath('./bin/background_foreground_to_stimulus_csv.sh')

    BACKGROUND_FOREGROUND_TO_STIMULUS_CSV(
        ch_input_for_formatting,
        ch_awk_program.collect()
    )
    ch_versions = ch_versions.mix(BACKGROUND_FOREGROUND_TO_STIMULUS_CSV.out.versions)

    emit:
    data = BACKGROUND_FOREGROUND_TO_STIMULUS_CSV.out.output
    versions = ch_versions
}
