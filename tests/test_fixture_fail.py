def test_instructor_fixture_failure():
    # Intentional failure — proves CI surfaces red builds.
    assert False, "instructor-provided failing test fixture"
