-- First, let's verify and fix the votes table
DROP POLICY IF EXISTS "Authenticated users can vote once per poll" ON votes;
DROP POLICY IF EXISTS "Only admins can view all votes" ON votes;

-- Recreate the votes table with proper constraints
CREATE TABLE IF NOT EXISTS votes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  poll_id UUID REFERENCES polls(id) ON DELETE CASCADE NOT NULL,
  option_id UUID REFERENCES options(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  UNIQUE(poll_id, user_id)
);

-- Create better indexes for performance
CREATE INDEX IF NOT EXISTS votes_poll_user_idx ON votes(poll_id, user_id);
CREATE INDEX IF NOT EXISTS votes_option_poll_idx ON votes(option_id, poll_id);

-- Fix RLS policies for votes
CREATE POLICY "Anyone can view vote counts"
  ON votes FOR SELECT
  USING (true);

CREATE POLICY "Users can vote once per poll"
  ON votes FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Must be the authenticated user
    auth.uid() = user_id
    -- Poll must exist and be active
    AND EXISTS (
      SELECT 1 FROM polls
      WHERE id = poll_id
      AND is_active = true
      AND ends_at > NOW()
    )
    -- Option must belong to the poll
    AND EXISTS (
      SELECT 1 FROM options
      WHERE id = option_id
      AND poll_id = votes.poll_id
    )
    -- User hasn't voted on this poll yet
    AND NOT EXISTS (
      SELECT 1 FROM votes
      WHERE poll_id = votes.poll_id
      AND user_id = auth.uid()
    )
  );

-- Enable RLS
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Enable realtime for votes
ALTER PUBLICATION supabase_realtime ADD TABLE votes;

-- Verify foreign key constraints
ALTER TABLE votes
  DROP CONSTRAINT IF EXISTS votes_poll_id_fkey,
  ADD CONSTRAINT votes_poll_id_fkey
    FOREIGN KEY (poll_id)
    REFERENCES polls(id)
    ON DELETE CASCADE;

ALTER TABLE votes
  DROP CONSTRAINT IF EXISTS votes_option_id_fkey,
  ADD CONSTRAINT votes_option_id_fkey
    FOREIGN KEY (option_id)
    REFERENCES options(id)
    ON DELETE CASCADE;

ALTER TABLE votes
  DROP CONSTRAINT IF EXISTS votes_user_id_fkey,
  ADD CONSTRAINT votes_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id);