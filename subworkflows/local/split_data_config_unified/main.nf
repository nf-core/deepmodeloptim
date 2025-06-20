/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { STIMULUS_SPLIT_YAML } from '../../../modules/local/stimulus/split_yaml'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SPLIT_DATA_CONFIG_UNIFIED_WF {
    take:
    ch_data_config

    main:

    ch_versions = Channel.empty()

    STIMULUS_SPLIT_YAML( ch_data_config )
    ch_versions = ch_versions.mix(STIMULUS_SPLIT_YAML.out.versions)

    // Process split configs - transpose and add split_id to meta
    ch_split_configs = STIMULUS_SPLIT_YAML.out.split_config
        .transpose()
        .map { meta, yaml -> 
            // Extract split info from descriptive filename
            def split_id = yaml.baseName.replaceAll(/.*_([^_]+_[^_]+)_split$/, '$1')
            [ meta + [split_id: split_id], yaml] 
        }

    // Process transform configs - transpose and add transform_id to meta  
    ch_transform_configs = STIMULUS_SPLIT_YAML.out.transform_config
        .transpose()
        .map { meta, yaml ->
            // Extract transform info from descriptive filename
            def transform_id = yaml.baseName.replaceAll(/.*_([^_]+_[^_]+)_transform$/, '$1')
            [ meta + [transform_id: transform_id], yaml]
        }

    // Encoding configs don't need transposition as there's only one per input
    ch_encoding_configs = STIMULUS_SPLIT_YAML.out.encode_config

    emit:
    split_config     = ch_split_configs     // channel: [ meta + [split_id: split_id], yaml ]
    transform_config = ch_transform_configs // channel: [ meta + [transform_id: transform_id], yaml ]
    encode_config    = ch_encoding_configs  // channel: [ meta, yaml ]
    versions         = ch_versions          // channel: [ versions.yml ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/