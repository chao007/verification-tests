Feature: oc_volume.feature

  # @author xxia@redhat.com
  # @case_id OCP-12194
  @smoke
  Scenario: Create a pod that consumes the secret in a volume
    Given I have a project
    When I run the :secrets client command with:
      | action         | new-basicauth     |
      | name           | basicsecret       |
      | username       | user-1            |
      | password       | pass-1            |
    Then the step should succeed
    When I run the :secrets client command with:
      | action         | add                    |
      | serviceaccount | serviceaccount/default |
      | secrets_name   | secret/basicsecret     |
    Then the step should succeed
    When I run the :run client command with:
      | name         | mydc                  |
      | image        | <%= project_docker_repo %>aosqe/hello-openshift |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=mydc-1 |
    When I run the :set_volume client command with:
      | resource      | dc                     |
      | resource_name | mydc                   |
      | action        | --add                  |
      | name          | secret-volume          |
      | type          | secret                 |
      | secret-name   | basicsecret            |
      | mount-path    | /etc/secret-volume-dir |
    Then the step should succeed

    Given a pod becomes ready with labels:
      | deployment=mydc-2 |
    When I execute on the pod:
      | cat | /etc/secret-volume-dir/username |
    Then the step should succeed
    And the output by order should contain:
      | user-1 |
    When I execute on the pod:
      | cat | /etc/secret-volume-dir/password |
    Then the step should succeed
    And the output by order should contain:
      | pass-1 |

  # @author xxia@redhat.com
  # @case_id OCP-11906
  @smoke
  Scenario: Add secret volume to dc and rc
    Given I have a project
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/misc/dc.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deploymentconfig=frontend |
    When I run the :create_secret client command with:
      | secret_type | generic    |
      | name        | my-secret  |
      | from_file   | /etc/hosts |
    Then the step should succeed

    Given I wait until replicationController "frontend-1" is ready
    When I run the :set_volume client command with:
      | resource      | rc                |
      | resource_name | frontend-1        |
      | action        | --add             |
      | name          | secret            |
      | type          | secret            |
      | secret-name   | my-secret         |
      | mount-path    | /etc              |
    Then the step should succeed

    When I run the :set_volume client command with:
      | resource      | dc                |
      | resource_name | frontend          |
      | action        | --add             |
      | name          | secret            |
      | type          | secret            |
      | secret-name   | my-secret         |
      | mount-path    | /etc              |
    Then the step should succeed

    When I run the :get client command with:
      | resource       | :false        |
      | resource_name  | dc/frontend   |
      | resource_name  | rc/frontend-2 |
      | o              | yaml          |
    Then the step should succeed
    # The output has "name: secret" prefixed with both "  " (2 spaces) and "- " ("-" and 1 space).
    # Using <%= "  name: secret" %> can reduce script lines. Otherwise, would contain 4 times of it
    And the output should contain 2 times:
      |   volumeMounts:            |
      |   - mountPath: /etc        |
      | <%= "  name: secret" %>    |
      | volumes:                   |
      | - name: secret             |
      |   secret:                  |
      |     secretName: my-secret  |
