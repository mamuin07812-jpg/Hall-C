BEGIN;

DROP POLICY IF EXISTS representative_read ON schoolivia.representative_assignments;
CREATE POLICY representative_read ON schoolivia.representative_assignments FOR SELECT TO authenticated USING
 (schoolivia.is_admin() OR student_id=schoolivia.current_profile_id() OR
 (active AND hall=(SELECT requester.hall FROM schoolivia.profiles requester WHERE requester.id=schoolivia.current_profile_id() AND requester.role='student' AND requester.profile_completed AND requester.email_verified AND NOT requester.blocked) AND
 EXISTS(SELECT 1 FROM schoolivia.profiles peer WHERE peer.id=schoolivia.representative_assignments.student_id AND peer.role='student' AND peer.profile_completed AND peer.email_verified AND NOT peer.blocked AND peer.hall=schoolivia.representative_assignments.hall)));

DROP POLICY IF EXISTS library_read ON schoolivia.library_items;
CREATE POLICY library_read ON schoolivia.library_items FOR SELECT TO authenticated USING
 (schoolivia.is_admin() OR EXISTS(SELECT 1 FROM schoolivia.profiles p WHERE p.id=schoolivia.current_profile_id() AND p.role='student' AND p.profile_completed AND NOT p.blocked));

DROP POLICY IF EXISTS schoolivia_library_storage_read ON storage.objects;
CREATE POLICY schoolivia_library_storage_read ON storage.objects FOR SELECT TO authenticated USING
 (bucket_id='schoolivia-library' AND (schoolivia.is_admin() OR EXISTS(SELECT 1 FROM schoolivia.profiles p WHERE p.id=schoolivia.current_profile_id() AND p.role='student' AND p.profile_completed AND NOT p.blocked AND p.stage IN ('Third Stage','third stage','Third','third','3'))));

INSERT INTO schoolivia_internal.schema_migrations(version) VALUES ('002_schoolivia_access_hardening') ON CONFLICT (version) DO NOTHING;
COMMIT;
