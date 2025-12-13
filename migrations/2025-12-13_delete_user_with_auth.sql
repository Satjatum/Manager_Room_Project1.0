-- ============================================
-- Migration: Fix User Deletion to Include Auth
-- Created: 2025-12-13
-- Purpose: Ensure that when deleting a user from public.users,
--          the corresponding auth.users record is also deleted
-- ============================================

-- Function: delete_user_completely
-- Description: Completely deletes a user from both public.users and auth.users
-- Parameters: p_user_id (UUID) - The user_id from public.users table
-- Returns: JSON with success status and message
-- Security: SECURITY DEFINER allows this function to delete from auth.users

CREATE OR REPLACE FUNCTION delete_user_completely(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_auth_uid UUID;
  v_user_name TEXT;
  v_result JSON;
BEGIN
  -- Step 1: Get auth_uid and user_name from public.users
  SELECT auth_uid, user_name INTO v_auth_uid, v_user_name
  FROM public.users
  WHERE user_id = p_user_id;
  
  -- Step 2: Check if user exists
  IF v_auth_uid IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'ไม่พบผู้ใช้ในระบบ'
    );
  END IF;
  
  -- Step 3: Delete from public.users first (this maintains referential integrity)
  DELETE FROM public.users WHERE user_id = p_user_id;
  
  -- Step 4: Delete from auth.users (requires SECURITY DEFINER)
  -- This removes the authentication credentials
  DELETE FROM auth.users WHERE id = v_auth_uid;
  
  -- Step 5: Return success
  RETURN json_build_object(
    'success', true,
    'message', 'ลบผู้ใช้ ' || v_user_name || ' และข้อมูล Auth เรียบร้อยแล้ว'
  );
  
EXCEPTION 
  WHEN foreign_key_violation THEN
    RETURN json_build_object(
      'success', false,
      'message', 'ไม่สามารถลบผู้ใช้ได้ เนื่องจากมีข้อมูลที่เกี่ยวข้องอยู่'
    );
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'เกิดข้อผิดพลาด: ' || SQLERRM
    );
END;
$$;

-- Grant execute permission to authenticated users (optional, adjust as needed)
-- GRANT EXECUTE ON FUNCTION delete_user_completely(UUID) TO authenticated;

-- ============================================
-- INSTRUCTIONS FOR DEPLOYMENT:
-- ============================================
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Copy and paste this entire SQL script
-- 3. Execute the script
-- 4. The function will be available for use via supabase.rpc('delete_user_completely', ...)
-- 
-- TESTING:
-- You can test the function with:
-- SELECT delete_user_completely('some-user-id-uuid');
-- ============================================
