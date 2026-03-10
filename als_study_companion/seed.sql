DO $$
DECLARE
  admin_id TEXT;
  c1 UUID := gen_random_uuid();
  c2 UUID := gen_random_uuid();
  c3 UUID := gen_random_uuid();
  c4 UUID := gen_random_uuid();
  l1 UUID := gen_random_uuid();
  l2 UUID := gen_random_uuid();
  l3 UUID := gen_random_uuid();
  l4 UUID := gen_random_uuid();
  l5 UUID := gen_random_uuid();
  l6 UUID := gen_random_uuid();
  l7 UUID := gen_random_uuid();
  l8 UUID := gen_random_uuid();
  qz1 UUID := gen_random_uuid();
  qz2 UUID := gen_random_uuid();
  qz3 UUID := gen_random_uuid();
  qz4 UUID := gen_random_uuid();
  qz5 UUID := gen_random_uuid();
  qz6 UUID := gen_random_uuid();
BEGIN
  SELECT id::text INTO admin_id FROM auth.users WHERE email = 'admin@als.edu.ph' LIMIT 1;

  IF admin_id IS NULL THEN
    RAISE EXCEPTION 'No admin user found. Please create admin@als.edu.ph in Authentication > Users first.';
  END IF;

  RAISE NOTICE 'Using admin_id: %', admin_id;

  INSERT INTO public.users (id, email, full_name, first_name, last_name, role, is_active, email_verified, teacher_verified, created_at, updated_at)
  VALUES (
    admin_id, 'admin@als.edu.ph', 'ALS Administrator', 'ALS', 'Administrator',
    'admin', true, true, true, NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET role = 'admin', is_active = true, teacher_verified = true, updated_at = NOW();

  -- ALS CENTERS
  INSERT INTO public.als_centers (id, name, address, region, contact_number, head_teacher_id, is_active, created_at, updated_at) VALUES
    (c1, 'ALS Center - Manila North', '123 Rizal Ave, Tondo, Manila', 'NCR', '+63-2-8123-4567', admin_id, true, NOW(), NOW()),
    (c2, 'ALS Center - Quezon City', '456 Commonwealth Ave, Quezon City', 'NCR', '+63-2-8234-5678', admin_id, true, NOW(), NOW()),
    (c3, 'ALS Center - Cebu City', '789 Osmena Blvd, Cebu City', 'Region VII', '+63-32-234-5678', admin_id, true, NOW(), NOW()),
    (c4, 'ALS Center - Davao', '321 Bolton St, Davao City', 'Region XI', '+63-82-234-5678', admin_id, true, NOW(), NOW());

  -- LESSONS
  INSERT INTO public.lessons (id, title, description, subject, grade_level, teacher_id, duration_minutes, order_index, is_published, created_at, updated_at) VALUES
    (l1, 'Introduction to Filipino Language', 'Learn the basics of Filipino - ang alpabeto, mga pangungusap, at pangunahing bokabularyo.', 'Filipino', 'Elementary', admin_id, 45, 1, true, NOW(), NOW()),
    (l2, 'Basic Mathematics: Whole Numbers', 'Understanding whole numbers, place value, and basic operations.', 'Mathematics', 'Elementary', admin_id, 50, 2, true, NOW(), NOW()),
    (l3, 'Philippine History: Pre-Colonial Period', 'Explore the rich history of the Philippines before Spanish colonization.', 'Social Studies', 'Secondary', admin_id, 60, 3, true, NOW(), NOW()),
    (l4, 'Basic Science: Living Things', 'Introduction to the classification of living organisms and ecosystems.', 'Science', 'Elementary', admin_id, 45, 4, true, NOW(), NOW()),
    (l5, 'English Communication Skills', 'Building confidence in English reading, writing, and speaking.', 'English', 'Elementary', admin_id, 50, 5, true, NOW(), NOW()),
    (l6, 'Digital Literacy Basics', 'Learn fundamental computer and internet skills for the modern world.', 'ICT', 'Elementary', admin_id, 40, 6, true, NOW(), NOW()),
    (l7, 'Values Education: Pagpapakatao', 'Understanding Filipino values, ethics, and moral development.', 'Values Education', 'Secondary', admin_id, 45, 7, true, NOW(), NOW()),
    (l8, 'Livelihood Skills: Basic Entrepreneurship', 'Introduction to starting a small business and financial literacy.', 'TLE', 'Secondary', admin_id, 55, 8, true, NOW(), NOW());

  -- QUIZZES
  INSERT INTO public.quizzes (id, lesson_id, title, description, time_limit_minutes, passing_score, order_index, is_published, created_at, updated_at) VALUES
    (qz1, l1::text, 'Filipino Basics Quiz', 'Test your knowledge of the Filipino alphabet and basic sentences.', 15, 70, 1, true, NOW(), NOW()),
    (qz2, l2::text, 'Whole Numbers Quiz', 'Practice problems on place value and basic operations.', 20, 70, 2, true, NOW(), NOW()),
    (qz3, l3::text, 'Pre-Colonial Philippines Quiz', 'Test your understanding of Philippine pre-colonial history.', 15, 70, 3, true, NOW(), NOW()),
    (qz4, l4::text, 'Living Things Quiz', 'Identify characteristics and classifications of living organisms.', 15, 70, 4, true, NOW(), NOW()),
    (qz5, l5::text, 'English Skills Quiz', 'Assess your English vocabulary and grammar skills.', 20, 70, 5, true, NOW(), NOW()),
    (qz6, l6::text, 'Digital Literacy Quiz', 'Test your knowledge of basic computer and internet concepts.', 15, 70, 6, true, NOW(), NOW());

  -- QUESTIONS
  INSERT INTO public.questions (id, quiz_id, question_text, question_type, options, correct_answer, order_index, points, created_at) VALUES
    (gen_random_uuid(), qz1::text, 'Ilan ang letra sa alpabetong Filipino?', 'multiple_choice', '["26", "27", "28", "30"]'::jsonb, '28', 1, 10, NOW()),
    (gen_random_uuid(), qz1::text, 'Alin ang tamang pangungusap?', 'multiple_choice', '["Ako ay masaya.", "Masaya ako ay.", "Ay ako masaya.", "Masaya ay ako."]'::jsonb, 'Ako ay masaya.', 2, 10, NOW()),
    (gen_random_uuid(), qz1::text, 'Ang salitang Magandang umaga ay ginagamit sa?', 'multiple_choice', '["Gabi", "Umaga", "Hapon", "Tanghali"]'::jsonb, 'Umaga', 3, 10, NOW()),
    (gen_random_uuid(), qz1::text, 'Ano ang kahulugan ng Bayanihan?', 'multiple_choice', '["Pagluluto", "Pagtutulungan", "Paglalaro", "Pagtulog"]'::jsonb, 'Pagtutulungan', 4, 10, NOW()),
    (gen_random_uuid(), qz2::text, 'What is the place value of 5 in 3,567?', 'multiple_choice', '["Ones", "Tens", "Hundreds", "Thousands"]'::jsonb, 'Hundreds', 1, 10, NOW()),
    (gen_random_uuid(), qz2::text, 'What is 456 + 278?', 'multiple_choice', '["724", "734", "634", "744"]'::jsonb, '734', 2, 10, NOW()),
    (gen_random_uuid(), qz2::text, 'What is 1,000 - 367?', 'multiple_choice', '["633", "643", "733", "637"]'::jsonb, '633', 3, 10, NOW()),
    (gen_random_uuid(), qz2::text, 'Which number is the largest?', 'multiple_choice', '["2345", "2435", "They are equal", "Cannot determine"]'::jsonb, '2435', 4, 10, NOW()),
    (gen_random_uuid(), qz3::text, 'What was the basic political unit in pre-colonial Philippines?', 'multiple_choice', '["Province", "Barangay", "Municipality", "Kingdom"]'::jsonb, 'Barangay', 1, 10, NOW()),
    (gen_random_uuid(), qz3::text, 'Who was the leader of a barangay?', 'multiple_choice', '["Sultan", "Datu", "Rajah", "Lakan"]'::jsonb, 'Datu', 2, 10, NOW()),
    (gen_random_uuid(), qz3::text, 'What was the ancient Filipino writing system called?', 'multiple_choice', '["Baybayin", "Kanji", "Sanskrit", "Latin"]'::jsonb, 'Baybayin', 3, 10, NOW()),
    (gen_random_uuid(), qz4::text, 'Which is a characteristic of living things?', 'multiple_choice', '["They are all green", "They all move fast", "They grow and reproduce", "They are all large"]'::jsonb, 'They grow and reproduce', 1, 10, NOW()),
    (gen_random_uuid(), qz4::text, 'Plants make their own food through?', 'multiple_choice', '["Digestion", "Photosynthesis", "Respiration", "Fermentation"]'::jsonb, 'Photosynthesis', 2, 10, NOW()),
    (gen_random_uuid(), qz4::text, 'Which kingdom do mushrooms belong to?', 'multiple_choice', '["Plant", "Animal", "Fungi", "Bacteria"]'::jsonb, 'Fungi', 3, 10, NOW()),
    (gen_random_uuid(), qz5::text, 'Choose the correct sentence:', 'multiple_choice', '["She go to school.", "She goes to school.", "She going to school.", "She gone to school."]'::jsonb, 'She goes to school.', 1, 10, NOW()),
    (gen_random_uuid(), qz5::text, 'What is the past tense of eat?', 'multiple_choice', '["Eated", "Ate", "Eaten", "Eating"]'::jsonb, 'Ate', 2, 10, NOW()),
    (gen_random_uuid(), qz5::text, 'Which word is a noun?', 'multiple_choice', '["Run", "Beautiful", "Happiness", "Quickly"]'::jsonb, 'Happiness', 3, 10, NOW()),
    (gen_random_uuid(), qz6::text, 'What does URL stand for?', 'multiple_choice', '["Universal Resource Link", "Uniform Resource Locator", "United Resource Location", "Universal Remote Locator"]'::jsonb, 'Uniform Resource Locator', 1, 10, NOW()),
    (gen_random_uuid(), qz6::text, 'Which of the following is a web browser?', 'multiple_choice', '["Microsoft Word", "Google Chrome", "Windows", "Photoshop"]'::jsonb, 'Google Chrome', 2, 10, NOW()),
    (gen_random_uuid(), qz6::text, 'What should you NEVER share online?', 'multiple_choice', '["Your favorite color", "Your password", "Your hobbies", "Your school name"]'::jsonb, 'Your password', 3, 10, NOW());

  -- SESSIONS
  INSERT INTO public.sessions (id, teacher_id, title, description, scheduled_at, duration_minutes, location, status, created_at, updated_at) VALUES
    (gen_random_uuid(), admin_id, 'Filipino Language Workshop', 'Interactive session on Filipino basics', '2026-03-15 09:00:00+08', 120, 'ALS Center - Manila North', 'scheduled', NOW(), NOW()),
    (gen_random_uuid(), admin_id, 'Math Review Session', 'Review of whole numbers and operations', '2026-03-16 13:00:00+08', 120, 'ALS Center - Manila North', 'scheduled', NOW(), NOW()),
    (gen_random_uuid(), admin_id, 'History Discussion', 'Group discussion on pre-colonial Philippines', '2026-03-17 10:00:00+08', 120, 'ALS Center - Quezon City', 'scheduled', NOW(), NOW()),
    (gen_random_uuid(), admin_id, 'Digital Skills Training', 'Hands-on computer basics training', '2026-03-18 14:00:00+08', 120, 'ALS Center - Cebu City', 'scheduled', NOW(), NOW());

  -- ANNOUNCEMENTS
  INSERT INTO public.announcements (id, teacher_id, title, message, target, is_pinned, created_at, updated_at) VALUES
    (gen_random_uuid(), admin_id, 'Welcome to ALS Study Companion!', 'We are excited to launch the ALS Study Companion app. This platform will help you access lessons, take quizzes, and track your learning progress anytime, anywhere. Happy learning!', '{}'::jsonb, true, NOW(), NOW()),
    (gen_random_uuid(), admin_id, 'New Schedule for Manila North Center', 'Starting March 15, 2026, our regular sessions will be held every Monday, Wednesday, and Friday from 9:00 AM to 12:00 PM.', '{}'::jsonb, false, NOW(), NOW()),
    (gen_random_uuid(), admin_id, 'A&E Review Classes Starting', 'Accreditation and Equivalency review classes will begin on March 20. All learners planning to take the A&E test are encouraged to attend.', '{}'::jsonb, true, NOW(), NOW()),
    (gen_random_uuid(), admin_id, 'App Update: Offline Mode Now Available', 'You can now download lessons for offline use! Go to any lesson and tap the download button. Your progress will sync automatically when you reconnect.', '{}'::jsonb, false, NOW(), NOW());

  RAISE NOTICE 'Seed data inserted successfully! Admin ID used: %', admin_id;
END $$;
