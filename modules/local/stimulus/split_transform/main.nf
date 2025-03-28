
process STIMULUS_SPLIT_TRANSFORM {

    tag "$meta.id"
    label 'process_low'
    // TODO: push image to nf-core quay.io
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(data_config)

    output:
    tuple val(meta), path ("*.yaml"), emit: sub_config
    path "versions.yml"          , emit: versions

    script:
    """
    stimulus split-transforms -y ${data_config}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    """
    touch test_0.yaml
    touch test_1.yaml
    touch test_2.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
