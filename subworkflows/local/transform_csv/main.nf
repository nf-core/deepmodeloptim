/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { STIMULUS_TRANSFORM_CSV } from '../../../modules/local/stimulus/transform_csv'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TRANSFORM_CSV_WF {

    take:
    ch_split_data
    ch_config_transform

    main:

    ch_versions = Channel.empty()


    // TODO add strategy for handling the launch of stimulus noiser as well as NF-core and other modules
    // TODO if the option is parellalization (for the above) then add csv column splitting  noising  merging

    // ==============================================================================
    // Transform data using stimulus
    // ==============================================================================

    // combine data vs configs based on common key: split_id
    ch_input = ch_split_data
        .map { meta, data ->
            [[split_id: meta.split_id], meta, data]
        }
        .combine(
            ch_config_transform.map { meta, config ->
                [[split_id: meta.split_id], meta, config]
            }
            ,by: 0
        )
        .multiMap{ key, meta_data, data, meta_config, config ->
            def meta = meta_data + [transform_id: meta_config.transform_id]
            data:
            [meta, data]
            config:
            [meta, config]
        }

    // run stimulus transform
    STIMULUS_TRANSFORM_CSV(
        ch_input.data,
        ch_input.config
    )
    ch_transformed_data = STIMULUS_TRANSFORM_CSV.out.transformed_data
    ch_versions = ch_versions.mix(STIMULUS_TRANSFORM_CSV.out.versions)

    emit:
    transformed_data = ch_transformed_data
    versions = ch_versions // channel: [ versions.yml ]
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
