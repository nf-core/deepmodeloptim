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
    pairs = predictions
        .collate(2)
        .collect()
        .map { items ->
            def pairs = []
            // Create all unique combinations using index comparison
            (0..<items.size()).each { i ->
                (i+1..<items.size()).each { j ->
                    def meta1 = items[i][0]
                    def meta2 = items[j][0]
                    def files = [items[i][1], items[j][1]]
                    // Only compare different transforms OR different replicates
                    if(meta1.transform_id != meta2.transform_id || meta1.replicate != meta2.replicate) {
                        pairs << [
                            [
                                "id1": meta1.id,
                                "id2": meta2.id,
                                "split_id1": meta1.split_id,
                                "split_id2": meta2.split_id,
                                "transform_id1": meta1.transform_id,
                                "transform_id2": meta2.transform_id,
                                "replicate1": meta1.replicate,
                                "replicate2": meta2.replicate
                            ],
                            // Create unique filenames using both transforms and replicates
                            files
                        ]
                    }
                }
            }
            pairs
        }
        .flatMap { it }

    //pairs.dump(tag: "pairs")


    STIMULUS_COMPARE_TENSORS_COSINE(
        pairs
    )

    cosine_scores = STIMULUS_COMPARE_TENSORS_COSINE.out.csv

    cosine_scores.dump(tag: "cosine_scores")

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
