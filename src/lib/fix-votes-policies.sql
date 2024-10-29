-- First, drop all existing policies on the votes table
DROP POLICY IF EXISTS "Authenticated users can vote once per poll" ON votes;
DROP POLICY IF EXISTS "Only admins can view all votes" ON votes;
DROP POLICY IF EXISTS "Users can view their own votes" ON votes;
DROP POLICY IF EXISTS "Admins can view all votes" ON votes;
DROP POLICY IF EXISTS "Users can vote once per active poll" ON votes;
DROP POLICY IF EXISTS "Anyone can view vote counts" ON votes;

-- Create a single, simple SELECT policy
CREATE POLICY "Anyone can view votes"
  ON votes FOR SELECT
  USING (true);

-- Create a straightforward INSERT policy without recursive checks
CREATE POLICY "Users can vote once"
  ON votes FOR INSERT
  WITH CHECK (
    -- Must be authenticated user
    auth.uid() = user_id
    -- Check if poll is active and not expired
    AND EXISTS (
      SELECT 1 FROM polls
      WHERE id = poll_id
      AND is_active = true
      AND ends_at > NOW()
    )
    -- Check if option belongs to poll (prevents voting for invalid options)
    AND EXISTS (
      SELECT 1 FROM options
      WHERE id = option_id
      AND poll_id = votes.poll_id
    )
  );

-- Ensure RLS is enabled
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Refresh the unique constraint to prevent double voting
ALTER TABLE votes DROP CONSTRAINT IF EXISTS votes_poll_id_user_id_key;
ALTER TABLE votes ADD CONSTRAINT votes_poll_id_user_id_key UNIQUE (poll_id, user_id);

-- Update indexes for better performance
DROP INDEX IF EXISTS votes_poll_user_idx;
DROP INDEX IF EXISTS votes_option_poll_idx;
CREATE INDEX votes_poll_user_idx ON votes(poll_id, user_id);
CREATE INDEX votes_option_poll_idx ON votes(option_id, poll_id);