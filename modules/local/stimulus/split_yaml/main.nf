process STIMULUS_SPLIT_YAML {

    tag "$meta.id"
    label 'process_low'
    // TODO: push image to nf-core quay.io
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(data_config)

    output:
    tuple val(meta), path("*_encode.yaml")     , emit: encode_config
    tuple val(meta), path("*_split.yaml")      , emit: split_config
    tuple val(meta), path("*_transform.yaml")  , emit: transform_config
    path "versions.yml"                        , emit: versions

    script:
    """
    stimulus split-yaml -y ${data_config} --out-dir ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    def prefix = data_config.baseName
    """
    touch ${prefix}_encode.yaml
    touch ${prefix}_RandomSplit_70-30_split.yaml
    touch ${prefix}_noise_std0.1_transform.yaml
    touch ${prefix}_noise_std0.2_transform.yaml
    touch ${prefix}_noise_std0.3_transform.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
