/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { STIMULUS_PREDICT                                                } from '../../../modules/local/stimulus/predict'
include { STIMULUS_COMPARE_TENSORS as STIMULUS_COMPARE_TENSORS_COSINE     } from '../../../modules/local/stimulus/compare_tensors'
include { CSVTK_CONCAT  as CONCAT_COSINE                                      } from '../../../modules/nf-core/csvtk/concat/main.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow EVALUATION_WF {
    take:
    model
    ch_data

    main:

    ch_versions = Channel.empty()

    //
    // Evaluation mode 1: Predict the data using the best model
    // and then compare the predictions of 2 different models
    //

    STIMULUS_PREDICT(
        model,
        ch_data.collect()
    )
    ch_versions = ch_versions.mix(STIMULUS_PREDICT.out.versions)
    predictions = STIMULUS_PREDICT.out.predictions

    // Now we can estimate the noise across replicates
    // This means: given a fixed initial model, initial data, and initial weights
    // and the same number of trials, we can estimate the noise across replicates
    // This is done by comparing the predictions of the alternative models between each other
    // and then calculatin a summary metric over them (e.g. mean, median, std, etc.)

    replicate_predictions = predictions.map{
                meta, prediction ->
                    [["id": meta.id,
                    "split_id": meta.split_id,
                    "transform_id": meta.transform_id,
                    "n_trials": meta.n_trials ], meta, prediction]
            }.groupTuple(by:0)
            .map{
                merging_meta, metas, predictions ->
                    [merging_meta, predictions]
            }

    // check if the predictions are at least 2, meta,predictions
    replicate_predictions.filter{
        it[1].size() > 1
    }.set{ replicate_predictions }

    STIMULUS_COMPARE_TENSORS_COSINE(
        replicate_predictions
    )

    cosine_scores = STIMULUS_COMPARE_TENSORS_COSINE.out.csv

    cosine_scores
    .map {
        meta, csv -> csv
    }
    .collect()
    .map {
        csv ->
            [ [ id:"summary_cosine" ], csv ]
    }
    .set { ch_cosine_summary }
    CONCAT_COSINE (ch_cosine_summary, "csv", "csv")

    emit:
    versions = ch_versions // channel: [ versions.yml ]

}
