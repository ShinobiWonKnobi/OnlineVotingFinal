-- Reset existing policies
DROP POLICY IF EXISTS "Only admins can view all votes" ON votes;
DROP POLICY IF EXISTS "Authenticated users can vote once per poll" ON votes;

-- Create improved voting policies
CREATE POLICY "Users can view their own votes"
  ON votes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all votes"
  ON votes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

CREATE POLICY "Users can vote once per active poll"
  ON votes FOR INSERT
  WITH CHECK (
    -- User must be authenticated
    auth.uid() = user_id
    -- Check if user hasn't voted on this poll yet
    AND NOT EXISTS (
      SELECT 1 FROM votes AS existing_votes
      WHERE existing_votes.poll_id = votes.poll_id
      AND existing_votes.user_id = auth.uid()
    )
    -- Check if poll is active and not expired
    AND EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = votes.poll_id
      AND polls.is_active = true
      AND polls.ends_at > NOW()
    )
  );